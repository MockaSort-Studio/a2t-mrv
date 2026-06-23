defmodule Livedata.Projects.ActivityChangesetTest do
  use ExUnit.Case, async: true
  import Livedata.DataCase, only: [errors_on: 1]

  alias Livedata.Projects.Activity

  @valid_project_id Ecto.UUID.generate()

  @valid_attrs %{
    name: "Test Activity",
    description: "A test carbon removal activity",
    activity_type: "PERMANENT_REMOVAL",
    storage_duration_tier: "PERMANENT",
    status: "REGISTERED",
    activity_period_start: ~D[2026-01-01],
    monitoring_period_start: ~D[2025-12-01]
  }

  describe "changeset/3 — validation" do
    test "default status is REGISTERED" do
      changeset =
        Activity.changeset(%Activity{}, @valid_project_id, Map.delete(@valid_attrs, :status))

      assert Ecto.Changeset.get_field(changeset, :status) == "REGISTERED"
    end

    test "missing name is rejected" do
      changeset =
        Activity.changeset(%Activity{}, @valid_project_id, Map.delete(@valid_attrs, :name))

      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    # @req: CRCF-34
    test "nil project_id is rejected" do
      changeset = Activity.changeset(%Activity{}, nil, @valid_attrs)
      assert %{project_id: ["can't be blank"]} = errors_on(changeset)
    end

    # @req: CRCF-13
    test "invalid activity_type is rejected" do
      changeset =
        Activity.changeset(
          %Activity{},
          @valid_project_id,
          Map.put(@valid_attrs, :activity_type, "INVALID")
        )

      assert %{activity_type: ["is invalid"]} = errors_on(changeset)
    end

    # @req: CRCF-13
    test "valid activity_types are accepted" do
      for type <-
            ~w(PERMANENT_REMOVAL FARMING_SEQUESTRATION PRODUCT_STORAGE SOIL_EMISSION_REDUCTION) do
        changeset =
          Activity.changeset(
            %Activity{},
            @valid_project_id,
            Map.put(@valid_attrs, :activity_type, type)
          )

        assert changeset.valid?, "expected #{type} to be valid"
      end
    end

    # @req: CRCF-14
    test "invalid storage_duration_tier is rejected" do
      changeset =
        Activity.changeset(
          %Activity{},
          @valid_project_id,
          Map.put(@valid_attrs, :storage_duration_tier, "INVALID")
        )

      assert %{storage_duration_tier: ["is invalid"]} = errors_on(changeset)
    end

    # @req: CRCF-14
    test "valid storage_duration_tiers are accepted" do
      for tier <- ~w(PERMANENT FARMING PRODUCTS) do
        changeset =
          Activity.changeset(
            %Activity{},
            @valid_project_id,
            Map.put(@valid_attrs, :storage_duration_tier, tier)
          )

        assert changeset.valid?, "expected #{tier} to be valid"
      end
    end
  end
end
