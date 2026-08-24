defmodule Livedata.ProjectsTest do
  use Livedata.DataCase, async: true

  @moduletag :integration

  alias Livedata.Projects
  alias Livedata.Projects.Project

  defp insert_project(name) do
    %Project{}
    |> Project.changeset(%{
      name: name,
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

  test "get_project!/1 fetches a project by id" do
    project = insert_project("Gamma")
    assert Projects.get_project!(project.id).name == "Gamma"
  end

  test "get_project!/1 raises for an unknown id" do
    assert_raise Ecto.NoResultsError, fn -> Projects.get_project!(Ecto.UUID.generate()) end
  end

  test "list_projects_with_stats/0 reports zeroes for a bare project" do
    insert_project("Empty")

    assert [stats] = Projects.list_projects_with_stats()
    assert stats.name == "Empty"
    assert stats.parcel_count == 0
    assert stats.activity_count == 0
    assert stats.measurement_count == 0
    assert stats.last_measured_at == nil
  end

  test "list_projects_with_stats/0 counts parcels and activities" do
    %{project: project} = Livedata.Fixtures.portfolio_fixture()
    Livedata.Fixtures.activity_fixture(project.id)

    assert [stats] = Projects.list_projects_with_stats()
    assert stats.parcel_count == 1
    assert stats.activity_count == 2
    assert stats.measurement_count == 0
  end

  test "list_activities_with_stats/1 joins the project and can filter by it" do
    %{project: project, activity: activity} = Livedata.Fixtures.portfolio_fixture()
    other = Livedata.Fixtures.project_fixture()
    Livedata.Fixtures.activity_fixture(other.id)

    assert length(Projects.list_activities_with_stats()) == 2

    assert [row] = Projects.list_activities_with_stats(project_id: project.id)
    assert row.id == activity.id
    assert row.project_name == project.name
    assert row.measurement_count == 0
  end
end
