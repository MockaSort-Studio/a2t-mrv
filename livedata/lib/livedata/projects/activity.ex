defmodule Livedata.Projects.Activity do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_activity_types ~w(PERMANENT_REMOVAL FARMING_SEQUESTRATION PRODUCT_STORAGE SOIL_EMISSION_REDUCTION)
  @valid_statuses ~w(REGISTERED ACTIVE MONITORING COMPLETED CERTIFIED CLOSED)

  @tier_by_type %{
    "PERMANENT_REMOVAL" => "PERMANENT",
    "FARMING_SEQUESTRATION" => "FARMING",
    "PRODUCT_STORAGE" => "PRODUCTS",
    # @req: CRCF-14 — SOIL_EMISSION_REDUCTION -> FARMING (inferred; pending domain sign-off)
    "SOIL_EMISSION_REDUCTION" => "FARMING"
  }

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

  # @req: CRCF-14
  defp validate_periods(changeset) do
    type = get_field(changeset, :activity_type)
    a_start = get_field(changeset, :activity_period_start)
    a_end = get_field(changeset, :activity_period_end)
    m_start = get_field(changeset, :monitoring_period_start)
    m_end = get_field(changeset, :monitoring_period_end)

    changeset
    |> then(fn cs ->
      if a_start && m_start && Date.compare(m_start, a_start) == :gt do
        add_error(cs, :monitoring_period_start, "must be on or before the activity start")
      else
        cs
      end
    end)
    |> validate_end_dates(type, a_end, m_end)
  end

  defp validate_end_dates(cs, "PERMANENT_REMOVAL", a_end, m_end) do
    cs
    |> reject_present(:activity_period_end, a_end)
    |> reject_present(:monitoring_period_end, m_end)
  end

  defp validate_end_dates(cs, _type, a_end, m_end) do
    cs =
      cs
      |> require_present(:activity_period_end, a_end)
      |> require_present(:monitoring_period_end, m_end)

    if a_end && m_end && Date.compare(m_end, a_end) == :lt do
      add_error(cs, :monitoring_period_end, "must be on or after the activity end")
    else
      cs
    end
  end

  defp reject_present(cs, _f, nil), do: cs
  defp reject_present(cs, f, _val), do: add_error(cs, f, "must be blank for permanent removal")
  defp require_present(cs, f, nil), do: add_error(cs, f, "can't be blank")
  defp require_present(cs, _f, _val), do: cs
end
