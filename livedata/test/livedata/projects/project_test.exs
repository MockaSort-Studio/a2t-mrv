defmodule Livedata.Projects.ProjectTest do
  use Livedata.DataCase, async: true

  @moduletag :integration

  alias Livedata.Projects.Project

  @valid_boundary %Geo.MultiPolygon{
    coordinates: [
      [
        [{0.0, 0.0}, {1.0, 0.0}, {1.0, 1.0}, {0.0, 1.0}, {0.0, 0.0}]
      ]
    ],
    srid: 4326
  }

  @valid_attrs %{
    name: "Test Project",
    description: "A test project",
    status: "DRAFT",
    spatial_boundary: @valid_boundary,
    commissioned_at: ~U[2026-01-01 00:00:00.000000Z]
  }

  describe "changeset/2 — persistence" do
    test "valid project can be persisted and retrieved by id" do
      assert {:ok, project} =
               %Project{} |> Project.changeset(@valid_attrs) |> Repo.insert()

      assert Repo.get(Project, project.id) != nil
    end

    test "project can be deleted" do
      {:ok, project} = %Project{} |> Project.changeset(@valid_attrs) |> Repo.insert()
      assert {:ok, _} = Repo.delete(project)
      assert Repo.get(Project, project.id) == nil
    end

    # @req: CRCF-20
    test "project fields can be updated; updated_at advances, inserted_at stays fixed" do
      {:ok, project} = %Project{} |> Project.changeset(@valid_attrs) |> Repo.insert()

      # Anchor updated_at to a known past value so the post-update timestamp must
      # strictly advance. Relying on the natural insert->update gap can read :eq
      # at :utc_datetime_usec resolution, which would let a non-advancing
      # updated_at pass silently.
      past = ~U[2020-01-01 00:00:00.000000Z]
      {1, _} = Repo.update_all(Project, set: [updated_at: past])
      project = Repo.get!(Project, project.id)
      original_inserted_at = project.inserted_at

      {:ok, updated} =
        project
        |> Project.changeset(%{name: "Renamed Project"})
        |> Repo.update()

      assert updated.inserted_at == original_inserted_at
      assert DateTime.compare(updated.updated_at, past) == :gt
    end

    # @req: CRCF-19
    test "id is auto-generated as UUID on insert" do
      {:ok, project} = %Project{} |> Project.changeset(@valid_attrs) |> Repo.insert()
      assert is_binary(project.id)
      assert {:ok, _} = Ecto.UUID.cast(project.id)
    end

    # @req: CRCF-20
    test "inserted_at, updated_at, and commissioned_at are UTC on insert" do
      {:ok, project} = %Project{} |> Project.changeset(@valid_attrs) |> Repo.insert()
      assert project.inserted_at.time_zone == "Etc/UTC"
      assert project.updated_at.time_zone == "Etc/UTC"
      assert project.commissioned_at.time_zone == "Etc/UTC"
    end
  end
end
