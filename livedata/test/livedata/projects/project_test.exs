defmodule Livedata.Projects.ProjectTest do
  use Livedata.DataCase, async: true

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

    test "project fields can be updated; updated_at advances, inserted_at stays fixed" do
      # @req: CRCF-20
      {:ok, project} = %Project{} |> Project.changeset(@valid_attrs) |> Repo.insert()
      original_inserted_at = project.inserted_at
      original_updated_at = project.updated_at

      {:ok, updated} =
        project
        |> Project.changeset(%{name: "Renamed Project"})
        |> Repo.update()

      assert updated.inserted_at == original_inserted_at
      assert DateTime.compare(updated.updated_at, original_updated_at) in [:gt, :eq]
    end

    test "id is auto-generated as UUID on insert" do
      # @req: CRCF-19
      {:ok, project} = %Project{} |> Project.changeset(@valid_attrs) |> Repo.insert()
      assert is_binary(project.id)
      assert {:ok, _} = Ecto.UUID.cast(project.id)
    end

    test "inserted_at, updated_at, and commissioned_at are UTC on insert" do
      # @req: CRCF-20
      {:ok, project} = %Project{} |> Project.changeset(@valid_attrs) |> Repo.insert()
      assert project.inserted_at.time_zone == "Etc/UTC"
      assert project.updated_at.time_zone == "Etc/UTC"
      assert project.commissioned_at.time_zone == "Etc/UTC"
    end
  end

  describe "changeset/2 — validation" do
    test "default status is DRAFT" do
      changeset = Project.changeset(%Project{}, Map.delete(@valid_attrs, :status))
      assert Ecto.Changeset.get_field(changeset, :status) == "DRAFT"
    end

    test "missing name is rejected" do
      changeset = Project.changeset(%Project{}, Map.delete(@valid_attrs, :name))
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "invalid status value is rejected" do
      changeset = Project.changeset(%Project{}, Map.put(@valid_attrs, :status, "INVALID"))
      assert %{status: ["is invalid"]} = errors_on(changeset)
    end

    test "geometrically invalid spatial_boundary is rejected" do
      # @req: CRCF-37
      wrong_type = %Geo.Point{coordinates: {1.0, 1.0}, srid: 4326}
      changeset = Project.changeset(%Project{}, Map.put(@valid_attrs, :spatial_boundary, wrong_type))
      assert %{spatial_boundary: [_msg]} = errors_on(changeset)
    end

    test "spatial_boundary with wrong SRID is rejected" do
      # @req: CRCF-37
      wrong_srid = %Geo.MultiPolygon{
        coordinates: [
          [
            [{0.0, 0.0}, {1.0, 0.0}, {1.0, 1.0}, {0.0, 1.0}, {0.0, 0.0}]
          ]
        ],
        srid: 3857
      }

      changeset =
        Project.changeset(%Project{}, Map.put(@valid_attrs, :spatial_boundary, wrong_srid))

      assert %{spatial_boundary: ["must use SRID 4326"]} = errors_on(changeset)
    end
  end
end
