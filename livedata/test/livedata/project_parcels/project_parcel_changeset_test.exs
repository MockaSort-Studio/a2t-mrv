defmodule Livedata.ProjectParcels.ProjectParcelChangesetTest do
  use ExUnit.Case, async: true
  import Livedata.DataCase, only: [errors_on: 1]

  alias Livedata.ProjectParcels.ProjectParcel

  @valid_project_id Ecto.UUID.generate()

  @valid_boundary %Geo.MultiPolygon{
    coordinates: [
      [
        [{0.0, 0.0}, {1.0, 0.0}, {1.0, 1.0}, {0.0, 1.0}, {0.0, 0.0}]
      ]
    ],
    srid: 4326
  }

  @valid_attrs %{
    parcel_ref: "LPIS-IT-001",
    data_source: "LPIS",
    boundary: @valid_boundary,
    commissioned_at: ~U[2026-01-01 00:00:00.000000Z]
  }

  describe "create_changeset/3 — validation" do
    # @req: CRCF-21
    test "nil project_id is rejected" do
      changeset = ProjectParcel.create_changeset(%ProjectParcel{}, nil, @valid_attrs)
      assert %{project_id: ["can't be blank"]} = errors_on(changeset)
    end

    test "missing parcel_ref is rejected" do
      changeset =
        ProjectParcel.create_changeset(
          %ProjectParcel{},
          @valid_project_id,
          Map.delete(@valid_attrs, :parcel_ref)
        )

      assert %{parcel_ref: ["can't be blank"]} = errors_on(changeset)
    end

    # @req: CRCF-36
    test "invalid data_source is rejected" do
      changeset =
        ProjectParcel.create_changeset(
          %ProjectParcel{},
          @valid_project_id,
          Map.put(@valid_attrs, :data_source, "INVALID")
        )

      assert %{data_source: ["is invalid"]} = errors_on(changeset)
    end

    # @req: CRCF-36
    test "valid data_sources LPIS and CADASTER are accepted" do
      for source <- ["LPIS", "CADASTER"] do
        changeset =
          ProjectParcel.create_changeset(
            %ProjectParcel{},
            @valid_project_id,
            Map.put(@valid_attrs, :data_source, source)
          )

        assert changeset.valid?, "expected #{source} to be valid"
      end
    end

  end
end
