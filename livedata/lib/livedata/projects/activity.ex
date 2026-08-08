defmodule Livedata.Projects.Activity do
  use Ecto.Schema
  import Ecto.Changeset

  alias Livedata.Projects.ActivityPeriods

  @valid_statuses ~w(REGISTERED ACTIVE MONITORING COMPLETED CERTIFIED CLOSED)

  @tier_by_type %{
    "PERMANENT_REMOVAL" => "PERMANENT",
    "FARMING_SEQUESTRATION" => "FARMING",
    "PRODUCT_STORAGE" => "PRODUCTS",
    # @req: CRCF-14 — SOIL_EMISSION_REDUCTION -> FARMING (inferred; pending domain sign-off)
    "SOIL_EMISSION_REDUCTION" => "FARMING"
  }

  # Derived from @tier_by_type so the valid-types list and the tier map can't drift apart.
  @valid_activity_types Map.keys(@tier_by_type)
  @non_permanent_types @valid_activity_types -- ["PERMANENT_REMOVAL"]

  @doc "The four statutory activity types. (@req: CRCF-13)"
  def activity_types, do: @valid_activity_types

  @doc "Activity types other than `PERMANENT_REMOVAL` — the ones with end dates."
  def non_permanent_types, do: @non_permanent_types

  @doc """
  The storage duration tier implied by an activity type. Tier is always derived,
  never taken from input. (@req: CRCF-14)
  """
  def tier_for_type(type), do: Map.get(@tier_by_type, type)

  # @req: CRCF-19
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # @req: CRCF-34
  schema "activities" do
    field :project_id, :binary_id
    field :name, :string
    field :description, :string
    # @req: CRCF-13
    field :activity_type, :string
    # @req: CRCF-14
    field :storage_duration_tier, :string
    field :status, :string, default: "REGISTERED"
    field :activity_period_start, :date
    field :activity_period_end, :date
    field :monitoring_period_start, :date
    field :monitoring_period_end, :date
    # @req: CRCF-20
    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(activity, project_id, attrs) do
    activity
    |> cast(attrs, [
      :name,
      :description,
      :activity_type,
      :status,
      :activity_period_start,
      :activity_period_end,
      :monitoring_period_start,
      :monitoring_period_end
    ])
    |> put_change(:project_id, project_id)
    |> validate_required([
      :project_id,
      :name,
      :activity_type,
      :status,
      :activity_period_start,
      :monitoring_period_start
    ])
    |> validate_inclusion(:activity_type, @valid_activity_types)
    |> validate_inclusion(:status, @valid_statuses)
    |> put_storage_duration_tier()
    |> validate_periods()
    |> foreign_key_constraint(:project_id)
  end

  # @req: CRCF-14 — tier is derived from type, never taken from input.
  defp put_storage_duration_tier(changeset) do
    case get_field(changeset, :activity_type) do
      nil -> changeset
      type -> put_change(changeset, :storage_duration_tier, @tier_by_type[type])
    end
  end

  # @req: CRCF-14 — shared with the form schemas so the rule cannot drift.
  defp validate_periods(changeset) do
    ActivityPeriods.validate(changeset, @non_permanent_types)
  end
end
