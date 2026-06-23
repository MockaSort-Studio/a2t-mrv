defmodule Livedata.Projects.ActivityTest do
  use Livedata.DataCase, async: true

  @moduletag :integration

  alias Livedata.Projects.Project
  alias Livedata.Projects.Activity

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

  @valid_attrs %{
    name: "Test Activity",
    description: "A test carbon removal activity",
    activity_type: "PERMANENT_REMOVAL",
    storage_duration_tier: "PERMANENT",
    status: "REGISTERED",
    activity_period_start: ~D[2026-01-01],
    monitoring_period_start: ~D[2025-12-01]
  }

  defp insert_project! do
    %Project{} |> Project.changeset(@project_attrs) |> Repo.insert!()
  end

  describe "changeset/3 — persistence" do
    # @req: CRCF-34
    test "valid activity can be persisted and retrieved by id" do
      project = insert_project!()

      assert {:ok, activity} =
               %Activity{}
               |> Activity.changeset(project.id, @valid_attrs)
               |> Repo.insert()

      assert Repo.get(Activity, activity.id) != nil
    end

    test "activity can be deleted" do
      project = insert_project!()

      {:ok, activity} =
        %Activity{}
        |> Activity.changeset(project.id, @valid_attrs)
        |> Repo.insert()

      assert {:ok, _} = Repo.delete(activity)
      assert Repo.get(Activity, activity.id) == nil
    end

    # @req: CRCF-19
    test "id is auto-generated as UUID on insert" do
      project = insert_project!()

      {:ok, activity} =
        %Activity{}
        |> Activity.changeset(project.id, @valid_attrs)
        |> Repo.insert()

      assert is_binary(activity.id)
      assert {:ok, _} = Ecto.UUID.cast(activity.id)
    end

    # @req: CRCF-20
    test "inserted_at and updated_at are UTC on insert" do
      project = insert_project!()

      {:ok, activity} =
        %Activity{}
        |> Activity.changeset(project.id, @valid_attrs)
        |> Repo.insert()

      assert activity.inserted_at.time_zone == "Etc/UTC"
      assert activity.updated_at.time_zone == "Etc/UTC"
    end

    # @req: CRCF-20
    test "updated_at advances on update; inserted_at unchanged" do
      project = insert_project!()

      {:ok, activity} =
        %Activity{}
        |> Activity.changeset(project.id, @valid_attrs)
        |> Repo.insert()

      past = ~U[2020-01-01 00:00:00.000000Z]
      {1, _} = Repo.update_all(Activity, set: [updated_at: past])
      activity = Repo.get!(Activity, activity.id)
      original_inserted_at = activity.inserted_at

      {:ok, updated} =
        activity
        |> Activity.changeset(project.id, %{name: "Renamed Activity"})
        |> Repo.update()

      assert updated.inserted_at == original_inserted_at
      assert DateTime.compare(updated.updated_at, past) == :gt
    end
  end
end
