defmodule Livedata.Registration.FormTest do
  use ExUnit.Case, async: true
  import Livedata.DataCase, only: [errors_on: 1]

  alias Livedata.Registration.Form

  @multipolygon ~s({"type":"MultiPolygon","coordinates":[[[[0.0,0.0],[1.0,0.0],[1.0,1.0],[0.0,1.0],[0.0,0.0]]]]})

  @valid %{
    "project_name" => "Test Project",
    "project_description" => "A test project",
    "project_boundary_geojson" => @multipolygon,
    "parcel_ref" => "LPIS-IT-001",
    "parcel_data_source" => "LPIS",
    "parcel_boundary_geojson" => @multipolygon
  }

  test "valid attrs produce a valid changeset" do
    assert Form.changeset(%Form{}, @valid).valid?
  end

  test "description is optional" do
    assert Form.changeset(%Form{}, Map.delete(@valid, "project_description")).valid?
  end

  test "missing required fields are rejected" do
    errors = errors_on(Form.changeset(%Form{}, %{}))

    for f <- [
          :project_name,
          :project_boundary_geojson,
          :parcel_ref,
          :parcel_data_source,
          :parcel_boundary_geojson
        ] do
      assert errors[f] == ["can't be blank"], "expected #{f} to be required"
    end
  end

  # @req: CRCF-36
  test "invalid data source is rejected" do
    cs = Form.changeset(%Form{}, Map.put(@valid, "parcel_data_source", "NOPE"))
    assert %{parcel_data_source: ["is invalid"]} = errors_on(cs)
  end

  # @req: CRCF-37
  test "non-MultiPolygon boundary is rejected" do
    point = ~s({"type":"Point","coordinates":[0.0,0.0]})
    cs = Form.changeset(%Form{}, Map.put(@valid, "project_boundary_geojson", point))
    assert %{project_boundary_geojson: ["must be a GeoJSON MultiPolygon"]} = errors_on(cs)
  end

  # @req: CRCF-37
  test "malformed JSON boundary is rejected" do
    cs = Form.changeset(%Form{}, Map.put(@valid, "parcel_boundary_geojson", "broken {"))
    assert %{parcel_boundary_geojson: ["is not valid JSON"]} = errors_on(cs)
  end
end
