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

  describe "create_activity/2" do
    defp methodology_fixture do
      Repo.insert!(
        Livedata.Projects.Methodology.changeset(%Livedata.Projects.Methodology{}, %{
          name: "M#{System.unique_integer([:positive])}"
        })
      )
    end

    defp activity_params(overrides \\ %{}) do
      Map.merge(
        %{
          "activity_name" => "Second activity",
          "activity_type" => "PERMANENT_REMOVAL",
          "activity_period_start" => "2026-01-01",
          "monitoring_period_start" => "2025-12-01",
          "methodology_ids" => [methodology_fixture().id]
        },
        overrides
      )
    end

    # @req: CRCF-34, CRCF-35
    test "adds an activity with its methodology links to an existing project" do
      project = insert_project("Host")

      assert {:ok, %{activity: activity, methodologies: [link]}} =
               Projects.create_activity(project.id, activity_params())

      assert activity.project_id == project.id
      # @req: CRCF-14 — tier derived, never supplied.
      assert activity.storage_duration_tier == "PERMANENT"
      assert link.activity_id == activity.id
    end

    test "returns the form changeset for invalid input, writing nothing" do
      project = insert_project("Host")

      assert {:error, %Ecto.Changeset{} = changeset} =
               Projects.create_activity(project.id, activity_params(%{"activity_name" => ""}))

      assert %{activity_name: ["can't be blank"]} = errors_on(changeset)
      assert Projects.list_activities_with_stats(project_id: project.id) == []
    end

    # @req: CRCF-35 — an unknown methodology must roll the whole thing back.
    test "rolls back the activity when a methodology link fails" do
      project = insert_project("Host")

      assert {:error, %Ecto.Changeset{}} =
               Projects.create_activity(
                 project.id,
                 activity_params(%{"methodology_ids" => [Ecto.UUID.generate()]})
               )

      assert Projects.list_activities_with_stats(project_id: project.id) == []
    end

    # @req: CRCF-14
    test "rejects a monitoring period that starts after the activity" do
      project = insert_project("Host")

      assert {:error, changeset} =
               Projects.create_activity(
                 project.id,
                 activity_params(%{"monitoring_period_start" => "2026-06-01"})
               )

      assert %{monitoring_period_start: [_]} = errors_on(changeset)
    end
  end

  describe "get_activity_with_context!/1" do
    test "returns the activity with its project and methodology names" do
      %{project: project, activity: activity} = Livedata.Fixtures.portfolio_fixture()
      methodology = methodology_fixture()

      Repo.insert!(
        Livedata.Projects.ActivityMethodology.changeset(
          %Livedata.Projects.ActivityMethodology{},
          activity.id,
          %{methodology_id: methodology.id, applied_at: DateTime.utc_now()}
        )
      )

      result = Projects.get_activity_with_context!(activity.id)

      assert result.id == activity.id
      assert result.project_name == project.name
      assert result.methodologies == [methodology.name]
    end

    test "raises for an unknown activity" do
      assert_raise Ecto.NoResultsError, fn ->
        Projects.get_activity_with_context!(Ecto.UUID.generate())
      end
    end
  end
end
