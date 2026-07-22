defmodule Livedata.ProjectsTest do
  use Livedata.DataCase, async: true

  @moduletag :integration

  alias Livedata.Projects
  alias Livedata.Projects.Project

  @boundary %Geo.MultiPolygon{
    coordinates: [[[{0.0, 0.0}, {1.0, 0.0}, {1.0, 1.0}, {0.0, 1.0}, {0.0, 0.0}]]],
    srid: 4326
  }

  defp insert_project(name) do
    %Project{}
    |> Project.changeset(%{
      name: name,
      spatial_boundary: @boundary,
      commissioned_at: DateTime.utc_now()
    })
    |> Repo.insert!()
  end

  test "list_projects/0 returns all persisted projects" do
    insert_project("Alpha")
    insert_project("Beta")
    names = Projects.list_projects() |> Enum.map(& &1.name)
    assert "Alpha" in names
    assert "Beta" in names
    assert length(names) == 2
  end

  test "list_projects/0 returns [] when there are none" do
    assert Projects.list_projects() == []
  end
end
