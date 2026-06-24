defmodule Livedata.Geo.ValidationsTest do
  use ExUnit.Case, async: true
  import Livedata.DataCase, only: [errors_on: 1]

  import Livedata.Geo.Validations
  import Ecto.Changeset

  defp changeset(boundary) do
    {%{}, %{boundary: Geo.PostGIS.Geometry}}
    |> cast(%{boundary: boundary}, [:boundary])
    |> validate_spatial_boundary(:boundary)
  end

  # @req: CRCF-37
  describe "validate_spatial_boundary/2" do
    test "valid MultiPolygon with SRID 4326 is accepted" do
      cs =
        changeset(%Geo.MultiPolygon{
          coordinates: [[[{0.0, 0.0}, {1.0, 0.0}, {1.0, 1.0}, {0.0, 0.0}]]],
          srid: 4326
        })

      assert cs.valid?
    end

    test "wrong SRID is rejected" do
      cs =
        changeset(%Geo.MultiPolygon{
          coordinates: [[[{0.0, 0.0}, {1.0, 0.0}, {1.0, 1.0}, {0.0, 0.0}]]],
          srid: 3857
        })

      assert %{boundary: ["must use SRID 4326"]} = errors_on(cs)
    end

    test "non-MultiPolygon geometry is rejected" do
      cs = changeset(%Geo.Point{coordinates: {1.0, 1.0}, srid: 4326})
      assert %{boundary: [_msg]} = errors_on(cs)
    end

    test "nil passes through unchanged" do
      cs = changeset(nil)
      assert cs.errors == []
    end
  end
end
