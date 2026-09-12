defmodule Livedata.Measurements.CsvParserQuotingTest do
  use Livedata.DataCase, async: true

  @moduletag :integration

  alias Livedata.Fixtures
  alias Livedata.Measurements.{BulkImport, CsvParser}

  # ---------------------------------------------------------------------------
  # Field count — a quoted field in every position must not inflate the count
  # ---------------------------------------------------------------------------

  # @req: CRCF-27
  test "quoted first field produces correct field count" do
    fields = CsvParser.parse_fields(~s("a",b,c))
    assert length(fields) == 3
    assert fields == ["a", "b", "c"]
  end

  test "quoted middle field produces correct field count" do
    fields = CsvParser.parse_fields(~s(a,"b",c))
    assert length(fields) == 3
    assert fields == ["a", "b", "c"]
  end

  test "quoted last field produces correct field count" do
    fields = CsvParser.parse_fields(~s(a,b,"c"))
    assert length(fields) == 3
    assert fields == ["a", "b", "c"]
  end

  test "all fields quoted produces correct field count" do
    fields = CsvParser.parse_fields(~s("a","b","c"))
    assert length(fields) == 3
    assert fields == ["a", "b", "c"]
  end

  test "quoted field with embedded comma produces correct field count" do
    fields = CsvParser.parse_fields(~s(a,"b1,b2",c))
    assert length(fields) == 3
    assert fields == ["a", "b1,b2", "c"]
  end

  # ---------------------------------------------------------------------------
  # Column mapping — header name determines field, not position
  # ---------------------------------------------------------------------------

  # @req: CRCF-27
  test "columns are mapped by header name, not position" do
    csv = """
    values_json,measured_at,method,latitude,longitude,crs
    {"soc":1.0},2027-06-01T10:00:00Z,core_sample,45.77,7.77,EPSG:4326
    """

    assert {:ok, [row]} = CsvParser.parse(csv)
    assert row["measured_at"] == "2027-06-01T10:00:00Z"
    assert row["method"] == "core_sample"
    assert row["crs"] == "EPSG:4326"
  end

  # ---------------------------------------------------------------------------
  # CRS fidelity — quoted CRS must not be replaced by the default
  # ---------------------------------------------------------------------------

  # @req: CRCF-16, CRCF-27
  test "explicit quoted CRS is preserved, not replaced by EPSG:4326 default" do
    csv = """
    measured_at,method,latitude,longitude,values_json,crs
    2027-06-01T10:00:00Z,core_sample,45.77,7.77,"{""soc"":9.9}",EPSG:3035
    """

    assert {:ok, [row]} = CsvParser.parse(csv)
    assert row["crs"] == "EPSG:3035"
  end

  test "quoted CRS in non-trailing position is preserved" do
    csv = """
    measured_at,method,crs,latitude,longitude,values_json
    2027-06-01T10:00:00Z,core_sample,EPSG:25832,45.77,7.77,{"soc":9.9}
    """

    assert {:ok, [row]} = CsvParser.parse(csv)
    assert row["crs"] == "EPSG:25832"
  end

  test "blank crs column still defaults to EPSG:4326" do
    csv = """
    measured_at,method,latitude,longitude,crs,values_json
    2027-06-01T10:00:00Z,core_sample,45.77,7.77,,{"soc":9.9}
    """

    assert {:ok, [row]} = CsvParser.parse(csv)
    assert row["crs"] == "EPSG:4326"
  end

  # ---------------------------------------------------------------------------
  # Error message interpolation — @req: CRCF-38
  # ---------------------------------------------------------------------------

  # @req: CRCF-38
  test "validation error messages have placeholders substituted" do
    %{activity: activity} = Fixtures.portfolio_fixture()

    csv = """
    measured_at,method,latitude,longitude,crs,values_json
    2026-07-01T10:00:00Z,core,999,7.6,EPSG:4326,{"soc":1.0}
    """

    assert {:error, errors} = BulkImport.import_csv(activity.id, csv)
    lat_error = Enum.find(errors, &(&1.field == :latitude))
    assert lat_error != nil
    refute lat_error.message =~ "%{number}", "placeholder not substituted: #{lat_error.message}"
    assert lat_error.message =~ "90"
  end

  # ---------------------------------------------------------------------------
  # UTF-8 BOM stripping
  # ---------------------------------------------------------------------------

  test "file with UTF-8 BOM is parsed correctly" do
    bom = "﻿"

    csv =
      bom <>
        """
        measured_at,method,latitude,longitude,crs,values_json
        2026-07-01T10:00:00Z,core,45.1,7.6,EPSG:4326,{"soc":1.0}
        """

    assert {:ok, [row]} = CsvParser.parse(csv)
    assert row["measured_at"] == "2026-07-01T10:00:00Z"
    assert row["crs"] == "EPSG:4326"
  end

  # ---------------------------------------------------------------------------
  # Whitespace around the delimiter — the form documents the spaced layout
  # ---------------------------------------------------------------------------

  # A closing quote is not always followed immediately by the comma. Treating
  # "anything but a comma" as end-of-line silently drops every later field.
  test "a closing quote followed by space then comma keeps the later fields" do
    assert CsvParser.parse_fields(~s|a,"b" ,c|) == ["a", "b", "c"]
  end

  test "an all-quoted row with spaces around the delimiters keeps every field" do
    assert CsvParser.parse_fields(~s|"a" , "b" , c|) == ["a", "b", " c"]
  end

  # @req: CRCF-16 — same silent CRS substitution as the trailing-comma bug,
  # reached through a space between the closing quote and the delimiter.
  test "crs after a space-separated delimiter is preserved" do
    csv =
      ~s|measured_at,method,latitude,longitude,values_json,crs\n| <>
        ~s|2027-06-01T10:00:00Z,core,45.77,7.77,"{""soc"":9.9}" ,EPSG:3035\n|

    assert {:ok, [row]} = CsvParser.parse(csv)
    assert row["crs"] == "EPSG:3035"
  end

  # MeasurementUploadLive prints the contract as
  # "measured_at, method, latitude, longitude, crs, values_json" — with spaces.
  test "whitespace before an opening quote does not cancel quoting" do
    assert CsvParser.parse_fields(~s|a, "b,c", d|) == ["a", "b,c", " d"]
  end

  test "parses the spaced layout the upload form documents" do
    csv =
      ~s|measured_at, method, latitude, longitude, crs, values_json\n| <>
        ~s|2027-06-04T10:00:00Z, core, 45.6, 7.6, EPSG:4326, "{""soc"":1.0,""ph"":6.5}"\n|

    assert {:ok, [row]} = CsvParser.parse(csv)
    assert row["method"] == "core"
    assert row["crs"] == "EPSG:4326"
    assert row["values_json"] == ~s|{"soc":1.0,"ph":6.5}|
  end

  test "an empty quoted field is one empty field" do
    assert CsvParser.parse_fields(~s|a,"",c|) == ["a", "", "c"]
  end

  test "a doubled quote inside a quoted field is one literal quote" do
    assert CsvParser.parse_fields(~s|a,"say ""hi""",c|) == ["a", ~s|say "hi"|, "c"]
  end

  # ---------------------------------------------------------------------------
  # Activity scoping and provenance constraints
  # ---------------------------------------------------------------------------

  # Entry.activity_id is :binary_id on an embedded schema, where Ecto's cast only
  # checks is_binary/1 — so a non-UUID reaches Repo.insert and raises
  # Ecto.ChangeError, which the ConstraintError rescue does not catch.
  test "rejects a malformed activity_id without raising" do
    csv = """
    measured_at,method,latitude,longitude,crs,values_json
    2027-08-04T10:00:00Z,core,45.1,7.6,EPSG:4326,{"soc":1.0}
    """

    assert {:error, [error]} = BulkImport.import_csv("not-a-uuid", csv)
    assert error.field == :activity_id
    assert Livedata.Repo.aggregate(Livedata.Measurements.RawMeasurement, :count) == 0
  end

  # @req: CRCF-16 — the projection is required provenance, so a value outside the
  # supported set must be rejected. raw_measurements is append-only (CRCF-26), so
  # an uninterpretable crs could never be corrected in place.
  test "rejects a crs outside the supported projections" do
    %{activity: activity} = Fixtures.portfolio_fixture()

    csv = """
    measured_at,method,latitude,longitude,crs,values_json
    2027-08-05T10:00:00Z,core,45.1,7.6,BANANA,{"soc":1.0}
    """

    assert {:error, errors} = BulkImport.import_csv(activity.id, csv)
    assert Enum.any?(errors, &(&1.field == :crs))
    assert Livedata.Repo.aggregate(Livedata.Measurements.RawMeasurement, :count) == 0
  end
end
