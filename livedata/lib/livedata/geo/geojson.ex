defmodule Livedata.Geo.GeoJSON do
  @moduledoc """
  Decode/encode helpers between GeoJSON strings and `Geo` structs.
  GeoJSON coordinates are WGS84, so decoded geometries are stamped SRID 4326.
  """

  # @req: CRCF-37
  @spec decode_multipolygon(binary()) ::
          {:ok, %Geo.MultiPolygon{}}
          | {:error, :invalid_json | :not_multipolygon | :invalid_geojson}
  def decode_multipolygon(string) when is_binary(string) do
    with {:ok, map} <- Jason.decode(string),
         {:ok, geometry} <- Geo.JSON.decode(map) do
      case geometry do
        %Geo.MultiPolygon{} = mp -> {:ok, %{mp | srid: 4326}}
        _other -> {:error, :not_multipolygon}
      end
    else
      {:error, %Jason.DecodeError{}} -> {:error, :invalid_json}
      {:error, _reason} -> {:error, :invalid_geojson}
    end
  end

  @spec encode_geometry(Geo.geometry()) :: map()
  def encode_geometry(geometry), do: Geo.JSON.encode!(geometry)
end
