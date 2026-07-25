defmodule Livedata.Registration.FormTest do
  use ExUnit.Case, async: true
  import Livedata.DataCase, only: [errors_on: 1]

  alias Livedata.Registration.Form

  @multipolygon ~s({"type":"MultiPolygon","coordinates":[[[[0.0,0.0],[1.0,0.0],[1.0,1.0],[0.0,1.0],[0.0,0.0]]]]})

  @valid_attrs %{
    "project_name" => "Test Project",
    "project_description" => "A test project",
    "parcel_ref" => "LPIS-IT-001",
    "parcel_data_source" => "LPIS",
    "parcel_boundary_geojson" => @multipolygon,
    "activity_name" => "Test Activity",
    "activity_type" => "PERMANENT_REMOVAL",
    "activity_period_start" => "2026-01-01",
    "monitoring_period_start" => "2025-12-01",
    "methodology_ids" => [Ecto.UUID.generate()]
  }

  test "valid attrs produce a valid changeset" do
    assert Form.changeset(%Form{}, @valid_attrs).valid?
  end

  test "description is optional" do
    assert Form.changeset(%Form{}, Map.delete(@valid_attrs, "project_description")).valid?
  end

  test "missing required fields are rejected" do
    errors = errors_on(Form.changeset(%Form{}, %{}))

    for f <- [
          :project_name,
          :parcel_ref,
          :parcel_data_source,
          :parcel_boundary_geojson,
          :activity_period_start,
          :monitoring_period_start
        ] do
      assert errors[f] == ["can't be blank"], "expected #{f} to be required"
    end
  end

  # @req: CRCF-36
  test "invalid data source is rejected" do
    cs = Form.changeset(%Form{}, Map.put(@valid_attrs, "parcel_data_source", "NOPE"))
    assert %{parcel_data_source: ["is invalid"]} = errors_on(cs)
  end

  # @req: CRCF-37
  test "non-MultiPolygon boundary is rejected" do
    point = ~s({"type":"Point","coordinates":[0.0,0.0]})
    cs = Form.changeset(%Form{}, Map.put(@valid_attrs, "parcel_boundary_geojson", point))
    assert %{parcel_boundary_geojson: ["must be a GeoJSON MultiPolygon"]} = errors_on(cs)
  end

  # @req: CRCF-37
  test "malformed JSON boundary is rejected" do
    cs = Form.changeset(%Form{}, Map.put(@valid_attrs, "parcel_boundary_geojson", "broken {"))
    assert %{parcel_boundary_geojson: ["is not valid JSON"]} = errors_on(cs)
  end

  # @req: CRCF-13
  test "activity fields are required" do
    cs = Form.changeset(%Form{}, Map.drop(@valid_attrs, ["activity_name", "activity_type"]))
    errors = errors_on(cs)
    assert errors[:activity_name] && errors[:activity_type]
  end

  # @req: CRCF-35
  test "at least one methodology is required" do
    cs = Form.changeset(%Form{}, Map.put(@valid_attrs, "methodology_ids", []))
    assert %{methodology_ids: [_]} = errors_on(cs)
  end

  # @req: CRCF-14
  test "monitoring start after activity start is rejected" do
    attrs =
      Map.merge(@valid_attrs, %{
        "activity_period_start" => "2026-01-01",
        "monitoring_period_start" => "2026-03-01"
      })

    assert %{monitoring_period_start: [_]} = errors_on(Form.changeset(%Form{}, attrs))
  end

  # @req: CRCF-14
  test "PERMANENT_REMOVAL rejects an activity end date" do
    attrs =
      Map.merge(@valid_attrs, %{
        "activity_type" => "PERMANENT_REMOVAL",
        "activity_period_end" => "2030-01-01"
      })

    assert %{activity_period_end: [_]} = errors_on(Form.changeset(%Form{}, attrs))
  end

  # @req: CRCF-14
  test "PERMANENT_REMOVAL flags both end dates when both are present" do
    attrs =
      Map.merge(@valid_attrs, %{
        "activity_type" => "PERMANENT_REMOVAL",
        "activity_period_end" => "2030-01-01",
        "monitoring_period_end" => "2030-06-01"
      })

    errors = errors_on(Form.changeset(%Form{}, attrs))
    assert %{activity_period_end: [_]} = errors
    assert %{monitoring_period_end: [_]} = errors
  end
end
