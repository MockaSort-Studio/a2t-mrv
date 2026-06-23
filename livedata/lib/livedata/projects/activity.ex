defmodule Livedata.Projects.Activity do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_activity_types ~w(PERMANENT_REMOVAL FARMING_SEQUESTRATION PRODUCT_STORAGE SOIL_EMISSION_REDUCTION)
  @valid_storage_duration_tiers ~w(PERMANENT FARMING PRODUCTS)
  @valid_statuses ~w(REGISTERED ACTIVE MONITORING COMPLETED CERTIFIED CLOSED)

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
      :storage_duration_tier,
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
      :storage_duration_tier,
      :status,
      :activity_period_start,
      :monitoring_period_start
    ])
    |> validate_inclusion(:activity_type, @valid_activity_types)
    |> validate_inclusion(:storage_duration_tier, @valid_storage_duration_tiers)
    |> validate_inclusion(:status, @valid_statuses)
    |> foreign_key_constraint(:project_id)
  end
end
