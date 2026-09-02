defmodule Livedata.Measurements.CsvImportTest do
  use Livedata.DataCase, async: false

  @moduletag :integration

  alias Livedata.Fixtures
  alias Livedata.Measurements.{BulkImport, CsvParser}
  alias Livedata.Measurements.RawMeasurement

  # ---------------------------------------------------------------------------
  # CsvParser
  # ---------------------------------------------------------------------------

  describe "CsvParser.parse/1" do
    test "parses a well-formed CSV into row attr maps" do
      csv = """
      measured_at,method,latitude,longitude,crs,values_json
      2026-07-01T10:00:00Z,core,45.1,7.6,EPSG:4326,{"soc":2.3}
      """

      assert {:ok, [row]} = CsvParser.parse(csv)
      assert row["measured_at"] == "2026-07-01T10:00:00Z"
      assert row["method"] == "core"
      assert row["latitude"] == "45.1"
      assert row["longitude"] == "7.6"
      assert row["crs"] == "EPSG:4326"
      assert row["values_json"] =~ "soc"
    end

    test "defaults crs to EPSG:4326 when column is blank" do
      csv = """
      measured_at,method,latitude,longitude,crs,values_json
      2026-07-01T10:00:00Z,core,45.1,7.6,,{"soc":1.0}
      """

      assert {:ok, [row]} = CsvParser.parse(csv)
      assert row["crs"] == "EPSG:4326"
    end

    test "returns error when header is missing required columns" do
      csv = "measured_at,method\n2026-07-01T10:00:00Z,core\n"
      assert {:error, :invalid_header} = CsvParser.parse(csv)
    end

    test "returns error when file is empty" do
      assert {:error, :empty_file} = CsvParser.parse("")
      assert {:error, :empty_file} = CsvParser.parse("\n")
    end

    test "returns error when there are no data rows" do
      csv = "measured_at,method,latitude,longitude,crs,values_json\n"
      assert {:error, :no_data_rows} = CsvParser.parse(csv)
    end

    test "attaches 1-based row numbers to each parsed row" do
      csv = """
      measured_at,method,latitude,longitude,crs,values_json
      2026-07-01T10:00:00Z,core,45.1,7.6,EPSG:4326,"{\"soc\":1.0}"
      2026-07-02T10:00:00Z,core,45.1,7.6,EPSG:4326,"{\"soc\":2.0}"
      """

      assert {:ok, rows} = CsvParser.parse(csv)
      assert length(rows) == 2
      assert Enum.at(rows, 0)["_row"] == 1
      assert Enum.at(rows, 1)["_row"] == 2
    end
  end

  # ---------------------------------------------------------------------------
  # BulkImport
  # ---------------------------------------------------------------------------

  describe "BulkImport.import_csv/2" do
    defp valid_csv(_activity_id) do
      """
      measured_at,method,latitude,longitude,crs,values_json
      2026-07-01T10:00:00Z,core,45.1,7.6,EPSG:4326,{"soc":2.3}
      2026-07-02T10:00:00Z,core,45.2,7.7,EPSG:4326,{"soc":3.1}
      """
    end

    # @req: CRCF-27 — all rows inserted in one transaction on a valid file
    test "inserts all rows on a valid file" do
      %{activity: activity} = Fixtures.portfolio_fixture()
      assert {:ok, rows} = BulkImport.import_csv(activity.id, valid_csv(activity.id))
      assert length(rows) == 2
      assert Repo.aggregate(RawMeasurement, :count) == 2
    end

    test "sets source_type to MANUAL_ENTRY and computes content_hash for each row" do
      %{activity: activity} = Fixtures.portfolio_fixture()
      {:ok, [rm | _]} = BulkImport.import_csv(activity.id, valid_csv(activity.id))
      assert rm.source_type == "MANUAL_ENTRY"
      assert is_binary(rm.content_hash) and byte_size(rm.content_hash) == 64
    end

    # @req: CRCF-27 — one invalid row causes the entire batch to be rejected
    test "rejects the whole batch when one row is invalid, writing nothing" do
      %{activity: activity} = Fixtures.portfolio_fixture()

      csv = """
      measured_at,method,latitude,longitude,crs,values_json
      2026-07-01T10:00:00Z,core,45.1,7.6,EPSG:4326,{"soc":2.3}
      bad-date,core,45.1,7.6,EPSG:4326,{"soc":3.1}
      """

      assert {:error, errors} = BulkImport.import_csv(activity.id, csv)
      assert Repo.aggregate(RawMeasurement, :count) == 0
      assert Enum.any?(errors, &(&1.row == 2))
    end

    # @req: CRCF-38 — errors identify row + field
    test "reports row number and field name for each validation error" do
      %{activity: activity} = Fixtures.portfolio_fixture()

      csv = """
      measured_at,method,latitude,longitude,crs,values_json
      2026-07-01T10:00:00Z,,999,7.6,EPSG:4326,{"soc":2.3}
      """

      assert {:error, errors} = BulkImport.import_csv(activity.id, csv)
      assert Enum.any?(errors, &(&1.row == 1 && &1.field in [:method, :latitude]))
    end

    # @req: CRCF-28 — duplicate within the same batch is rejected
    test "rejects a batch where two rows have identical content" do
      %{activity: activity} = Fixtures.portfolio_fixture()

      csv = """
      measured_at,method,latitude,longitude,crs,values_json
      2026-07-01T10:00:00Z,core,45.1,7.6,EPSG:4326,{"soc":2.3}
      2026-07-01T10:00:00Z,core,45.1,7.6,EPSG:4326,{"soc":2.3}
      """

      assert {:error, errors} = BulkImport.import_csv(activity.id, csv)
      assert Repo.aggregate(RawMeasurement, :count) == 0
      assert Enum.any?(errors, &(&1.field == :content_hash))
    end

    # @req: CRCF-28 — duplicate against an existing stored measurement
    test "rejects a row that duplicates a measurement already in the database" do
      %{activity: activity} = Fixtures.portfolio_fixture()

      Fixtures.measurement_fixture(activity.id, ~U[2026-07-01 10:00:00.000000Z], %{"soc" => 2.3})

      csv = """
      measured_at,method,latitude,longitude,crs,values_json
      2026-07-01T10:00:00Z,core,45.1,7.6,EPSG:4326,{"soc":2.3}
      """

      assert {:error, errors} = BulkImport.import_csv(activity.id, csv)
      assert Enum.any?(errors, &(&1.field == :content_hash))
    end

    test "forwards CsvParser errors" do
      %{activity: activity} = Fixtures.portfolio_fixture()
      assert {:error, :invalid_header} = BulkImport.import_csv(activity.id, "a,b\n1,2\n")
    end
  end
end
