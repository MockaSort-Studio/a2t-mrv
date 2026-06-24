defmodule Livedata.Projects.ActivityMethodologyTest do
  use Livedata.DataCase, async: true

  @moduletag :integration

  alias Livedata.Projects.Activity
  alias Livedata.Projects.ActivityMethodology
  alias Livedata.Projects.Project

  @valid_boundary %Geo.MultiPolygon{
    coordinates: [
      [
        [{0.0, 0.0}, {1.0, 0.0}, {1.0, 1.0}, {0.0, 1.0}, {0.0, 0.0}]
      ]
    ],
    srid: 4326
  }

  @project_attrs %{
    name: "Test Project",
    status: "DRAFT",
    spatial_boundary: @valid_boundary,
    commissioned_at: ~U[2026-01-01 00:00:00.000000Z]
  }

  @activity_attrs %{
    name: "Test Activity",
    activity_type: "PERMANENT_REMOVAL",
    storage_duration_tier: "PERMANENT",
    status: "REGISTERED",
    activity_period_start: ~D[2026-01-01],
    monitoring_period_start: ~D[2025-12-01]
  }

  defp insert_project! do
    %Project{} |> Project.changeset(@project_attrs) |> Repo.insert!()
  end

  defp insert_activity!(project_id) do
    %Activity{}
    |> Activity.changeset(project_id, @activity_attrs)
    |> Repo.insert!()
  end

  defp methodology_id, do: Ecto.UUID.generate()

  describe "activity_methodology persistence" do
    # @req: CRCF-35
    test "row can be associated to a valid activity" do
      project = insert_project!()
      activity = insert_activity!(project.id)

      assert {:ok, am} =
               %ActivityMethodology{}
               |> ActivityMethodology.changeset(activity.id, %{
                 methodology_id: methodology_id(),
                 applied_at: ~U[2026-06-01 00:00:00.000000Z]
               })
               |> Repo.insert()

      assert am.activity_id == activity.id
    end

    # @req: CRCF-35
    test "duplicate (activity_id, methodology_id) pair is rejected at DB level" do
      project = insert_project!()
      activity = insert_activity!(project.id)
      mid = methodology_id()
      attrs = %{methodology_id: mid, applied_at: ~U[2026-06-01 00:00:00.000000Z]}

      %ActivityMethodology{}
      |> ActivityMethodology.changeset(activity.id, attrs)
      |> Repo.insert!()

      assert {:error, changeset} =
               %ActivityMethodology{}
               |> ActivityMethodology.changeset(activity.id, attrs)
               |> Repo.insert()

      assert changeset.errors != []
    end

    # @req: CRCF-20
    test "applied_at is UTC on insert" do
      project = insert_project!()
      activity = insert_activity!(project.id)

      {:ok, am} =
        %ActivityMethodology{}
        |> ActivityMethodology.changeset(activity.id, %{
          methodology_id: methodology_id(),
          applied_at: ~U[2026-06-01 12:30:00.000000Z]
        })
        |> Repo.insert()

      assert am.applied_at.time_zone == "Etc/UTC"
    end

    test "row can be deleted" do
      project = insert_project!()
      activity = insert_activity!(project.id)

      {:ok, am} =
        %ActivityMethodology{}
        |> ActivityMethodology.changeset(activity.id, %{
          methodology_id: methodology_id(),
          applied_at: ~U[2026-06-01 00:00:00.000000Z]
        })
        |> Repo.insert()

      assert {:ok, _} = Repo.delete(am)

      assert Repo.get_by(ActivityMethodology,
               activity_id: am.activity_id,
               methodology_id: am.methodology_id
             ) == nil
    end
  end
end
