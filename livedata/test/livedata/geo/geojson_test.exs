defmodule Livedata.Geo.GeoJSONTest do
  use ExUnit.Case, async: true

  alias Livedata.Geo.GeoJSON

  @multipolygon_json ~s({"type":"MultiPolygon","coordinates":[[[[0.0,0.0],[1.0,0.0],[1.0,1.0],[0.0,1.0],[0.0,0.0]]]]})
  @point_json ~s({"type":"Point","coordinates":[0.0,0.0]})

  describe "decode_multipolygon/1" do
    test "decodes a GeoJSON MultiPolygon into a Geo.MultiPolygon with SRID 4326" do
      assert {:ok, %Geo.MultiPolygon{srid: 4326}} =
               GeoJSON.decode_multipolygon(@multipolygon_json)
    end

    test "rejects malformed JSON" do
      assert {:error, :invalid_json} = GeoJSON.decode_multipolygon("not json {")
    end

    test "rejects non-MultiPolygon geometry" do
      assert {:error, :not_multipolygon} = GeoJSON.decode_multipolygon(@point_json)
    end

    test "rejects valid JSON that is not GeoJSON" do
      assert {:error, :invalid_geojson} = GeoJSON.decode_multipolygon(~s({"foo":"bar"}))
    end
  end

  describe "encode_geometry/1" do
    test "round-trips a MultiPolygon back to a GeoJSON geometry map" do
      {:ok, geom} = GeoJSON.decode_multipolygon(@multipolygon_json)
      assert %{"type" => "MultiPolygon", "coordinates" => _} = GeoJSON.encode_geometry(geom)
    end
  end
end
