defmodule Livedata.ProjectParcels.ProjectParcelTest do
  use Livedata.DataCase, async: true

  @moduletag :integration

  alias Livedata.Projects.Project
  alias Livedata.ProjectParcels.ProjectParcel

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

  @parcel_attrs %{
    parcel_ref: "LPIS-IT-001",
    data_source: "LPIS",
    boundary: @valid_boundary,
    commissioned_at: ~U[2026-01-01 00:00:00.000000Z]
  }

  defp insert_project! do
    %Project{} |> Project.changeset(@project_attrs) |> Repo.insert!()
  end

  describe "create_changeset/3 — persistence" do
    # @req: CRCF-21
    test "valid parcel can be inserted and retrieved by id" do
      project = insert_project!()

      assert {:ok, parcel} =
               %ProjectParcel{}
               |> ProjectParcel.create_changeset(project.id, @parcel_attrs)
               |> Repo.insert()

      assert Repo.get(ProjectParcel, parcel.id) != nil
    end

    # @req: CRCF-21
    test "parcel is deleted when its project is deleted (cascade)" do
      project = insert_project!()

      {:ok, parcel} =
        %ProjectParcel{}
        |> ProjectParcel.create_changeset(project.id, @parcel_attrs)
        |> Repo.insert()

      Repo.delete!(project)
      assert Repo.get(ProjectParcel, parcel.id) == nil
    end

    # @req: CRCF-21
    test "inserting with non-existent project_id returns FK error" do
      bogus_id = Ecto.UUID.generate()

      assert {:error, changeset} =
               %ProjectParcel{}
               |> ProjectParcel.create_changeset(bogus_id, @parcel_attrs)
               |> Repo.insert()

      assert %{project_id: ["does not exist"]} = errors_on(changeset)
    end

    # @req: CRCF-19
    test "id is auto-generated as UUID on insert" do
      project = insert_project!()

      {:ok, parcel} =
        %ProjectParcel{}
        |> ProjectParcel.create_changeset(project.id, @parcel_attrs)
        |> Repo.insert()

      assert is_binary(parcel.id)
      assert {:ok, _} = Ecto.UUID.cast(parcel.id)
    end

    # @req: CRCF-20
    test "inserted_at, updated_at, and commissioned_at are UTC on insert" do
      project = insert_project!()

      {:ok, parcel} =
        %ProjectParcel{}
        |> ProjectParcel.create_changeset(project.id, @parcel_attrs)
        |> Repo.insert()

      assert parcel.inserted_at.time_zone == "Etc/UTC"
      assert parcel.updated_at.time_zone == "Etc/UTC"
      assert parcel.commissioned_at.time_zone == "Etc/UTC"
    end
  end
end
