defmodule Livedata.Projects.ProjectChangesetTest do
  use ExUnit.Case, async: true
  import Livedata.DataCase, only: [errors_on: 1]

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

  end
end
