defmodule Livedata.Projects.ProjectChangesetTest do
  use ExUnit.Case, async: true
  import Livedata.DataCase, only: [errors_on: 1]

  alias Livedata.Projects.Project

  @valid_attrs %{
    name: "Test Project",
    description: "A test project",
    status: "DRAFT",
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
