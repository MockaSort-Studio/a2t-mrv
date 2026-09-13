defmodule Livedata.Measurements.IngestionModeTest do
  use Livedata.DataCase, async: true

  @moduletag :integration

  # @req: CRCF-04, CRCF-22
  alias Livedata.Fixtures
  alias Livedata.Measurements
  alias Livedata.Measurements.{BulkImport, RawMeasurement}

  defp valid_form_attrs(activity_id) do
    %{
      "activity_id" => activity_id,
      "measured_at" => "2026-07-01T10:00:00Z",
      "method" => "core",
      "latitude" => "45.1",
      "longitude" => "7.6",
      "crs" => "EPSG:4326",
      "values_json" => ~s({"soc":2.3})
    }
  end

  defp valid_csv do
    """
    measured_at,method,latitude,longitude,crs,values_json
    2026-07-02T10:00:00Z,core,45.1,7.6,EPSG:4326,{"soc":9.9}
    """
  end

  # @req: CRCF-04 — manual form records FORM_ENTRY
  test "create_raw_measurement/1 sets ingestion_mode to FORM_ENTRY" do
    %{activity: activity} = Fixtures.portfolio_fixture()

    assert {:ok, %RawMeasurement{} = rm} =
             Measurements.create_raw_measurement(valid_form_attrs(activity.id))

    assert rm.ingestion_mode == "FORM_ENTRY"
  end

  # @req: CRCF-22 — CSV upload records CSV_UPLOAD
  test "BulkImport.import_csv/2 sets ingestion_mode to CSV_UPLOAD" do
    %{activity: activity} = Fixtures.portfolio_fixture()
    assert {:ok, [rm | _]} = BulkImport.import_csv(activity.id, valid_csv())
    assert rm.ingestion_mode == "CSV_UPLOAD"
  end

  # @req: CRCF-28 — same measurement via both routes is still a duplicate
  test "same measurement submitted via form then CSV is rejected as duplicate" do
    %{activity: activity} = Fixtures.portfolio_fixture()

    form_attrs = valid_form_attrs(activity.id)
    assert {:ok, _} = Measurements.create_raw_measurement(form_attrs)

    # Same measurement data submitted via CSV (same source_type MANUAL_ENTRY, same values)
    csv = """
    measured_at,method,latitude,longitude,crs,values_json
    2026-07-01T10:00:00Z,core,45.1,7.6,EPSG:4326,{"soc":2.3}
    """

    assert {:error, errors} = BulkImport.import_csv(activity.id, csv)
    assert Enum.any?(errors, &(&1.field == :content_hash))
  end

  # @req: CRCF-28 — same measurement via CSV then form is still a duplicate
  test "same measurement submitted via CSV then form is rejected as duplicate" do
    %{activity: activity} = Fixtures.portfolio_fixture()

    csv = """
    measured_at,method,latitude,longitude,crs,values_json
    2026-07-01T10:00:00Z,core,45.1,7.6,EPSG:4326,{"soc":2.3}
    """

    assert {:ok, _} = BulkImport.import_csv(activity.id, csv)

    form_attrs = valid_form_attrs(activity.id)
    assert {:error, :duplicate} = Measurements.create_raw_measurement(form_attrs)
  end

  # ingestion_mode cannot be spoofed via form params
  test "ingestion_mode is ignored when present in form params" do
    %{activity: activity} = Fixtures.portfolio_fixture()

    attrs = Map.put(valid_form_attrs(activity.id), "ingestion_mode", "CSV_UPLOAD")
    assert {:ok, %RawMeasurement{} = rm} = Measurements.create_raw_measurement(attrs)
    assert rm.ingestion_mode == "FORM_ENTRY"
  end

  # ingestion_mode cannot be spoofed via a CSV column
  test "ingestion_mode column in CSV is ignored" do
    %{activity: activity} = Fixtures.portfolio_fixture()

    csv =
      ~s|measured_at,method,latitude,longitude,crs,values_json,ingestion_mode\n| <>
        ~s|2026-07-01T10:00:00Z,core,45.1,7.6,EPSG:4326,{"soc":2.3},FORM_ENTRY\n|

    assert {:ok, [rm]} = BulkImport.import_csv(activity.id, csv)
    assert rm.ingestion_mode == "CSV_UPLOAD"
  end

  # FORM_ENTRY and CSV_UPLOAD are distinguishable in the database
  test "measurements from both routes are distinguishable by ingestion_mode" do
    %{activity: activity} = Fixtures.portfolio_fixture()

    assert {:ok, form_rm} = Measurements.create_raw_measurement(valid_form_attrs(activity.id))
    assert {:ok, [csv_rm]} = BulkImport.import_csv(activity.id, valid_csv())

    assert form_rm.ingestion_mode != csv_rm.ingestion_mode
    assert form_rm.ingestion_mode == "FORM_ENTRY"
    assert csv_rm.ingestion_mode == "CSV_UPLOAD"
  end
end
