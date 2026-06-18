defmodule Livedata.Geo.Validations do
  import Ecto.Changeset

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
