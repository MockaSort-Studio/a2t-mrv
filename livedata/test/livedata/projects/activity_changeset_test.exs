defmodule Livedata.Projects.ActivityChangesetTest do
  use ExUnit.Case, async: true
  import Livedata.DataCase, only: [errors_on: 1]

  alias Livedata.Projects.Activity

  @valid_project_id Ecto.UUID.generate()

  @valid_attrs %{
    name: "Test Activity",
    description: "A test carbon removal activity",
    activity_type: "PERMANENT_REMOVAL",
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
        attrs = @valid_attrs |> Map.put(:activity_type, type) |> permanent_dates(type)
        changeset = Activity.changeset(%Activity{}, @valid_project_id, attrs)

        assert changeset.valid?, "expected #{type} to be valid"
      end
    end

    # @req: CRCF-14 — tier derived from type (single source of truth)
    test "storage_duration_tier is derived from activity_type" do
      for {type, tier} <- [
            {"PERMANENT_REMOVAL", "PERMANENT"},
            {"FARMING_SEQUESTRATION", "FARMING"},
            {"PRODUCT_STORAGE", "PRODUCTS"},
            {"SOIL_EMISSION_REDUCTION", "FARMING"}
          ] do
        attrs = @valid_attrs |> Map.put(:activity_type, type) |> permanent_dates(type)
        cs = Activity.changeset(%Activity{}, @valid_project_id, attrs)
        assert Ecto.Changeset.get_field(cs, :storage_duration_tier) == tier
        assert cs.valid?, "expected #{type} valid"
      end
    end

    # @req: CRCF-14
    test "monitoring_period_start after activity_period_start is rejected" do
      attrs =
        Map.merge(@valid_attrs, %{
          activity_period_start: ~D[2026-01-01],
          monitoring_period_start: ~D[2026-02-01]
        })

      assert %{monitoring_period_start: [_]} =
               errors_on(Activity.changeset(%Activity{}, @valid_project_id, attrs))
    end

    # @req: CRCF-14
    test "PERMANENT_REMOVAL rejects non-nil end dates" do
      attrs =
        Map.merge(@valid_attrs, %{
          activity_type: "PERMANENT_REMOVAL",
          activity_period_end: ~D[2030-01-01]
        })

      assert %{activity_period_end: [_]} =
               errors_on(Activity.changeset(%Activity{}, @valid_project_id, attrs))
    end

    # @req: CRCF-14
    test "non-permanent type requires end dates and monitoring_end >= activity_end" do
      base = Map.merge(@valid_attrs, %{activity_type: "FARMING_SEQUESTRATION"})
      # missing ends
      assert %{activity_period_end: [_]} =
               errors_on(Activity.changeset(%Activity{}, @valid_project_id, base))

      # monitoring_end before activity_end
      bad =
        Map.merge(base, %{
          activity_period_end: ~D[2031-01-01],
          monitoring_period_end: ~D[2030-01-01]
        })

      assert %{monitoring_period_end: [_]} =
               errors_on(Activity.changeset(%Activity{}, @valid_project_id, bad))
    end
  end

  # permanent types must have nil ends; others need valid ends
  defp permanent_dates(attrs, "PERMANENT_REMOVAL"), do: attrs

  defp permanent_dates(attrs, _),
    do:
      Map.merge(attrs, %{
        activity_period_end: ~D[2031-01-01],
        monitoring_period_end: ~D[2032-01-01]
      })
end
