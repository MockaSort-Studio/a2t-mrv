defmodule Livedata.Projects.ActivityForm do
  @moduledoc """
  Embedded schema backing "add an activity to an existing project"
  (@req: CRCF-34). A project accumulates activities over its life; only the
  first one is born at commissioning.

  Field names match the activity section of `Livedata.Registration.Form` so
  both render through the same form component, and the period rules come from
  `Livedata.Projects.ActivityPeriods` so they cannot drift from the schema.
  `storage_duration_tier` is deliberately absent — it is derived from the type
  (@req: CRCF-14).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Livedata.Projects.{Activity, ActivityPeriods}

  @required ~w(activity_name activity_type activity_period_start monitoring_period_start)a
  @all @required ++
         ~w(activity_description activity_period_end monitoring_period_end methodology_ids)a

  @primary_key false
  embedded_schema do
    field :activity_name, :string
    field :activity_description, :string
    field :activity_type, :string
    field :activity_period_start, :date
    field :activity_period_end, :date
    field :monitoring_period_start, :date
    field :monitoring_period_end, :date
    field :methodology_ids, {:array, :binary_id}, default: []
  end

  def changeset(form, attrs) do
    form
    |> cast(attrs, @all)
    |> validate_required(@required)
    # @req: CRCF-13
    |> validate_inclusion(:activity_type, Activity.activity_types())
    # @req: CRCF-35 — force_change so validate_length runs even when the cast
    # value equals the [] default (see Registration.Form for the same guard).
    |> then(&force_change(&1, :methodology_ids, get_field(&1, :methodology_ids)))
    |> validate_length(:methodology_ids, min: 1, message: "select at least one methodology")
    # @req: CRCF-14
    |> ActivityPeriods.validate(Activity.non_permanent_types())
  end
end
