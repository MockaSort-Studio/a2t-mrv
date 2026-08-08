defmodule Livedata.Registration.Form do
  @moduledoc """
  Embedded schema backing the single project-registration form. Owns all
  form-level validation, including GeoJSON parsing, before the values are
  mapped onto the Project and ProjectParcel changesets in `Livedata.Registration`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Livedata.Geo.GeoJSON
  alias Livedata.Projects.ActivityPeriods

  @data_sources ~w(LPIS CADASTER)
  @activity_types ~w(PERMANENT_REMOVAL FARMING_SEQUESTRATION PRODUCT_STORAGE SOIL_EMISSION_REDUCTION)
  @non_permanent_activity_types @activity_types -- ["PERMANENT_REMOVAL"]

  @required ~w(project_name parcel_ref parcel_data_source parcel_boundary_geojson
    activity_name activity_type activity_period_start monitoring_period_start)a
  @all @required ++
         ~w(project_description activity_description activity_period_end monitoring_period_end)a ++
         [:methodology_ids]

  @primary_key false
  embedded_schema do
    field :project_name, :string
    field :project_description, :string
    field :parcel_ref, :string
    field :parcel_data_source, :string
    field :parcel_boundary_geojson, :string
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
    # @req: CRCF-36
    |> validate_inclusion(:parcel_data_source, @data_sources)
    # @req: CRCF-37 — the boundary is captured on the parcel, not on the project
    |> validate_geojson_multipolygon(:parcel_boundary_geojson)
    # @req: CRCF-13
    |> validate_inclusion(:activity_type, @activity_types)
    # @req: CRCF-35 — force_change so validate_length runs even when the cast value
    # equals the [] default (validate_length is validate_change-based and is a no-op
    # for fields absent from `changeset.changes`).
    |> then(&force_change(&1, :methodology_ids, get_field(&1, :methodology_ids)))
    |> validate_length(:methodology_ids, min: 1, message: "select at least one methodology")
    # @req: CRCF-14
    |> validate_activity_periods()
  end

  defp validate_geojson_multipolygon(changeset, field) do
    case get_field(changeset, field) do
      nil ->
        changeset

      value ->
        case GeoJSON.decode_multipolygon(value) do
          {:ok, _geom} ->
            changeset

          {:error, :invalid_json} ->
            add_error(changeset, field, "is not valid JSON")

          {:error, :not_multipolygon} ->
            add_error(changeset, field, "must be a GeoJSON MultiPolygon")

          {:error, :invalid_geojson} ->
            add_error(changeset, field, "is not valid GeoJSON")
        end
    end
  end

  # @req: CRCF-14 — same rules as Activity, surfaced on Form fields for live feedback.
  defp validate_activity_periods(changeset) do
    ActivityPeriods.validate(changeset, @non_permanent_activity_types)
  end
end
