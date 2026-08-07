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
    with {:ok, decoded} <- Jason.decode(string),
         :ok <- object?(decoded),
         {:ok, geometry} <- decode_geometry(decoded) do
      case geometry do
        %Geo.MultiPolygon{} = mp -> {:ok, %{mp | srid: 4326}}
        _other -> {:error, :not_multipolygon}
      end
    else
      {:error, %Jason.DecodeError{}} -> {:error, :invalid_json}
      {:error, _reason} -> {:error, :invalid_geojson}
    end
  end

  # A GeoJSON geometry is a JSON object. A bare array (pasting only the
  # coordinates is an easy mistake), number, string or boolean decodes as JSON
  # but makes `Geo.JSON.decode/1` raise BadMapError.
  defp object?(decoded) when is_map(decoded), do: :ok
  defp object?(_decoded), do: {:error, :not_an_object}

  # `Geo.JSON.decode/1` is specced to return a tagged tuple, but raises on
  # malformed coordinate payloads — a non-numeric coordinate (ArgumentError) or
  # the wrong nesting depth (Protocol.UndefinedError). This function is fed
  # unvalidated form input, and an exception here would take the calling
  # LiveView down and reset the form the operator was filling in.
  defp decode_geometry(map) do
    Geo.JSON.decode(map)
  rescue
    _exception -> {:error, :undecodable_geometry}
  end

  @spec encode_geometry(Geo.geometry()) :: map()
  def encode_geometry(geometry), do: Geo.JSON.encode!(geometry)
end
