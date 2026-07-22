defmodule Livedata.Registration.Form do
  @moduledoc """
  Embedded schema backing the single project-registration form. Owns all
  form-level validation, including GeoJSON parsing, before the values are
  mapped onto the Project and ProjectParcel changesets in `Livedata.Registration`.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Livedata.Geo.GeoJSON

  @data_sources ~w(LPIS CADASTER)
  @required ~w(project_name project_boundary_geojson parcel_ref parcel_data_source parcel_boundary_geojson)a
  @all ~w(project_name project_description project_boundary_geojson parcel_ref parcel_data_source parcel_boundary_geojson)a

  @primary_key false
  embedded_schema do
    field :project_name, :string
    field :project_description, :string
    field :project_boundary_geojson, :string
    field :parcel_ref, :string
    field :parcel_data_source, :string
    field :parcel_boundary_geojson, :string
  end

  def changeset(form, attrs) do
    form
    |> cast(attrs, @all)
    |> validate_required(@required)
    # @req: CRCF-36
    |> validate_inclusion(:parcel_data_source, @data_sources)
    # @req: CRCF-37
    |> validate_geojson_multipolygon(:project_boundary_geojson)
    |> validate_geojson_multipolygon(:parcel_boundary_geojson)
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
end
