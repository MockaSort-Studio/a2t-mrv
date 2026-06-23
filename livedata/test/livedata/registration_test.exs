defmodule Livedata.RegistrationTest do
  use Livedata.DataCase, async: true

  @moduletag :integration

  alias Livedata.Registration
  alias Livedata.Projects.Project
  alias Livedata.ProjectParcels.ProjectParcel

  @multipolygon ~s({"type":"MultiPolygon","coordinates":[[[[0.0,0.0],[1.0,0.0],[1.0,1.0],[0.0,1.0],[0.0,0.0]]]]})

  @valid %{
    "project_name" => "Test Project",
    "project_description" => "A test project",
    "project_boundary_geojson" => @multipolygon,
    "parcel_ref" => "LPIS-IT-001",
    "parcel_data_source" => "LPIS",
    "parcel_boundary_geojson" => @multipolygon
  }

  # @req: CRCF-21
  test "register/2 creates a project and its parcel in one transaction" do
    assert {:ok, %{project: project, parcel: parcel}} = Registration.register(@valid)
    assert %Project{} = Repo.get(Project, project.id)
    assert %ProjectParcel{} = Repo.get(ProjectParcel, parcel.id)
    assert parcel.project_id == project.id
    assert %Geo.MultiPolygon{srid: 4326} = project.spatial_boundary
    assert project.status == "DRAFT"
    assert project.commissioned_at != nil
  end

  test "register/2 with invalid input returns an error and writes nothing" do
    assert {:error, changeset} =
             Registration.register(Map.put(@valid, "parcel_data_source", "NOPE"))

    refute changeset.valid?
    assert Repo.aggregate(Project, :count) == 0
    assert Repo.aggregate(ProjectParcel, :count) == 0
  end
end
