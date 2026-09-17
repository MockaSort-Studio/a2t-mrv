defmodule Livedata.Geo.Validations do
  import Ecto.Changeset

  alias Livedata.Geo.GeoJSON

  # @req: CRCF-37
  def validate_geojson_multipolygon(changeset, field) do
    case get_field(changeset, field) do
      nil ->
        changeset

      value ->
        case GeoJSON.decode_multipolygon(value) do
          {:ok, _} ->
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

  # @req: CRCF-37
  def validate_spatial_boundary(changeset, field) do
    case get_field(changeset, field) do
      nil ->
        changeset

      %Geo.MultiPolygon{srid: 4326} ->
        changeset

      %Geo.MultiPolygon{} ->
        add_error(changeset, field, "must use SRID 4326")

      _ ->
        add_error(changeset, field, "must be a MultiPolygon with SRID 4326")
    end
  end
end
