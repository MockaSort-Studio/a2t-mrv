defmodule Livedata.ProjectParcelsTest do
  use Livedata.DataCase, async: true

  @moduletag :integration

  alias Livedata.ProjectParcels
  alias Livedata.ProjectParcels.ProjectParcel
  alias Livedata.Projects.Project

  @boundary %Geo.MultiPolygon{
    coordinates: [[[{0.0, 0.0}, {1.0, 0.0}, {1.0, 1.0}, {0.0, 1.0}, {0.0, 0.0}]]],
    srid: 4326
  }

  defp insert_project_with_parcel(name, parcel_ref) do
    commissioned_at = DateTime.utc_now()

    project =
      %Project{}
      |> Project.changeset(%{name: name, commissioned_at: commissioned_at})
      |> Repo.insert!()

    %ProjectParcel{}
    |> ProjectParcel.create_changeset(project.id, %{
      parcel_ref: parcel_ref,
      data_source: "LPIS",
      boundary: @boundary,
      commissioned_at: commissioned_at
    })
    |> Repo.insert!()

    project
  end

  # @req: CRCF-37
  test "list_parcels_with_project/0 returns each parcel's boundary with its project" do
    project = insert_project_with_parcel("Alpha", "LPIS-IT-001")

    assert [parcel] = ProjectParcels.list_parcels_with_project()
    assert parcel.project_id == project.id
    assert parcel.project_name == "Alpha"
    assert parcel.parcel_ref == "LPIS-IT-001"
    assert %Geo.MultiPolygon{srid: 4326} = parcel.boundary
  end

  test "list_parcels_with_project/0 returns [] when there are none" do
    assert ProjectParcels.list_parcels_with_project() == []
  end
end
