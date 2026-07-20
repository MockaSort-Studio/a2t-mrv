defmodule Livedata.Measurements.RawMeasurementTest do
  use Livedata.DataCase, async: false

  @moduletag :integration

  alias Livedata.Measurements.RawMeasurement
  alias Livedata.Projects.Activity
  alias Livedata.Projects.Project

  @valid_boundary %Geo.MultiPolygon{
    coordinates: [
      [
        [{0.0, 0.0}, {1.0, 0.0}, {1.0, 1.0}, {0.0, 1.0}, {0.0, 0.0}]
      ]
    ],
    srid: 4326
  }

  @project_attrs %{
    name: "Test Project",
    status: "DRAFT",
    spatial_boundary: @valid_boundary,
    commissioned_at: ~U[2026-01-01 00:00:00.000000Z]
  }

  @activity_attrs %{
    name: "Test Activity",
    activity_type: "PERMANENT_REMOVAL",
    storage_duration_tier: "PERMANENT",
    status: "REGISTERED",
    activity_period_start: ~D[2026-01-01],
    monitoring_period_start: ~D[2025-12-01]
  }

  # SHA-256 hex is 64 chars
  @base_measured_at ~U[2026-06-01 12:00:00.000000Z]
  @valid_attrs %{
    measured_at: @base_measured_at,
    source_type: "MANUAL_ENTRY",
    content_hash: "aaaaaaaaaaaa" <> String.duplicate("0", 52),
    provenance: %{"operator" => "test-user", "device" => "sensor-1"},
    values: %{"co2_kg" => 42.5}
  }

  defp insert_project!() do
    %Project{} |> Project.changeset(@project_attrs) |> Repo.insert!()
  end

  defp insert_activity!(project) do
    %Activity{} |> Activity.changeset(project.id, @activity_attrs) |> Repo.insert!()
  end

  defp insert_measurement!(activity, attrs \\ %{}) do
    %RawMeasurement{}
    |> RawMeasurement.changeset(activity.id, Map.merge(@valid_attrs, attrs))
    |> Repo.insert!()
  end

  # Postgrex sends UUID parameters in binary wire format; convert string UUIDs first
  defp uuid_bin(id), do: Ecto.UUID.dump!(id)

  describe "changeset/3 — persistence" do
    test "valid raw_measurement can be inserted and retrieved by id" do
      project = insert_project!()
      activity = insert_activity!(project)

      assert {:ok, m} =
               %RawMeasurement{}
               |> RawMeasurement.changeset(activity.id, @valid_attrs)
               |> Repo.insert()

      assert Repo.get(RawMeasurement, m.id) != nil
    end

    # @req: CRCF-19
    test "id is auto-generated as UUID on insert" do
      project = insert_project!()
      activity = insert_activity!(project)
      m = insert_measurement!(activity)

      assert is_binary(m.id)
      assert {:ok, _} = Ecto.UUID.cast(m.id)
    end

    # @req: CRCF-20
    test "inserted_at is UTC on insert" do
      project = insert_project!()
      activity = insert_activity!(project)
      m = insert_measurement!(activity)

      assert m.inserted_at.time_zone == "Etc/UTC"
    end

    # @req: CRCF-21
    test "activity_id is required; insert without it is rejected" do
      changeset = RawMeasurement.changeset(%RawMeasurement{}, nil, @valid_attrs)
      refute changeset.valid?
      assert %{activity_id: [_ | _]} = errors_on(changeset)
    end

    # @req: CRCF-04
    test "source_type is required; insert without it is rejected" do
      project = insert_project!()
      activity = insert_activity!(project)

      changeset =
        RawMeasurement.changeset(
          %RawMeasurement{},
          activity.id,
          Map.delete(@valid_attrs, :source_type)
        )

      refute changeset.valid?
      assert %{source_type: [_ | _]} = errors_on(changeset)
    end

    test "invalid source_type value is rejected by changeset" do
      project = insert_project!()
      activity = insert_activity!(project)

      changeset =
        RawMeasurement.changeset(
          %RawMeasurement{},
          activity.id,
          Map.put(@valid_attrs, :source_type, "INVALID_TYPE")
        )

      refute changeset.valid?
      assert %{source_type: [_ | _]} = errors_on(changeset)
    end

    # @req: CRCF-28 — unique_constraint name is chunk-specific in TimescaleDB, so ConstraintError is the expected raise
    test "duplicate content_hash is rejected at DB level" do
      project = insert_project!()
      activity = insert_activity!(project)
      insert_measurement!(activity)

      assert_raise Ecto.ConstraintError, fn ->
        %RawMeasurement{}
        |> RawMeasurement.changeset(activity.id, @valid_attrs)
        |> Repo.insert!()
      end
    end

    # @req: CRCF-04, CRCF-07
    test "provenance is required; insert without it is rejected" do
      project = insert_project!()
      activity = insert_activity!(project)

      changeset =
        RawMeasurement.changeset(
          %RawMeasurement{},
          activity.id,
          Map.delete(@valid_attrs, :provenance)
        )

      refute changeset.valid?
      assert %{provenance: [_ | _]} = errors_on(changeset)
    end

    # @req: CRCF-27
    test "values is required; insert without it is rejected" do
      project = insert_project!()
      activity = insert_activity!(project)

      changeset =
        RawMeasurement.changeset(
          %RawMeasurement{},
          activity.id,
          Map.delete(@valid_attrs, :values)
        )

      refute changeset.valid?
      assert %{values: [_ | _]} = errors_on(changeset)
    end

    test "is_superseded defaults to false" do
      project = insert_project!()
      activity = insert_activity!(project)
      m = insert_measurement!(activity)

      assert m.is_superseded == false
    end

    # @req: CRCF-26 — changeset-level validation; is_superseded must be in attrs for validate_supersession to run
    test "is_superseded = true with superseded_by = nil is rejected" do
      project = insert_project!()
      activity = insert_activity!(project)

      changeset =
        RawMeasurement.changeset(%RawMeasurement{}, activity.id, %{
          measured_at: @base_measured_at,
          source_type: "MANUAL_ENTRY",
          content_hash: "bbbbbbbbbbbb" <> String.duplicate("0", 52),
          provenance: %{"operator" => "test"},
          values: %{"co2_kg" => 1.0},
          is_superseded: true
        })

      refute changeset.valid?
      assert %{superseded_by: [_ | _]} = errors_on(changeset)
    end

    # @req: CRCF-26
    test "superseded_by = id (self-reference) is rejected" do
      self_id = Ecto.UUID.generate()
      project = insert_project!()
      activity = insert_activity!(project)

      changeset =
        RawMeasurement.changeset(%RawMeasurement{id: self_id}, activity.id, %{
          measured_at: @base_measured_at,
          source_type: "MANUAL_ENTRY",
          content_hash: "cccccccccccc" <> String.duplicate("0", 52),
          provenance: %{"operator" => "test"},
          values: %{"co2_kg" => 1.0},
          superseded_by: self_id
        })

      refute changeset.valid?
      assert %{superseded_by: [_ | _]} = errors_on(changeset)
    end

    # @req: CRCF-25, CRCF-26
    # Append-only supersession: the corrected record's ID is pre-generated so the superseded
    # record can reference it at INSERT time — no UPDATE on the original is needed or allowed.
    test "supersession chain — corrected record inserted, original marked superseded with valid superseded_by" do
      project = insert_project!()
      activity = insert_activity!(project)

      corrected_id = Ecto.UUID.generate()

      {:ok, corrected} =
        %RawMeasurement{id: corrected_id}
        |> RawMeasurement.changeset(activity.id, %{
          measured_at: ~U[2026-06-02 12:00:00.000000Z],
          source_type: "MANUAL_ENTRY",
          content_hash: "dddddddddddd" <> String.duplicate("0", 52),
          provenance: %{"operator" => "corrector"},
          values: %{"co2_kg" => 43.0}
        })
        |> Repo.insert()

      {:ok, superseded} =
        %RawMeasurement{}
        |> RawMeasurement.changeset(
          activity.id,
          Map.merge(@valid_attrs, %{
            is_superseded: true,
            superseded_by: corrected_id
          })
        )
        |> Repo.insert()

      assert superseded.is_superseded == true
      assert superseded.superseded_by == corrected.id
      assert Repo.get(RawMeasurement, superseded.id) != nil
      assert Repo.get(RawMeasurement, corrected.id) != nil
    end

    # @req: CRCF-25
    test "UPDATE on any raw_measurement row is rejected at DB level" do
      project = insert_project!()
      activity = insert_activity!(project)
      m = insert_measurement!(activity)

      assert_raise Postgrex.Error, ~r/raw_measurements is append-only/i, fn ->
        Repo.query!(
          "UPDATE raw_measurements SET content_hash = 'changed' WHERE id = $1",
          [uuid_bin(m.id)]
        )
      end
    end

    # @req: CRCF-25
    test "DELETE on any raw_measurement row is rejected at DB level" do
      project = insert_project!()
      activity = insert_activity!(project)
      m = insert_measurement!(activity)

      assert_raise Postgrex.Error, ~r/raw_measurements is append-only/i, fn ->
        Repo.query!("DELETE FROM raw_measurements WHERE id = $1", [uuid_bin(m.id)])
      end
    end

    # @req: CRCF-25
    test "UPDATE on a superseded row is also rejected" do
      project = insert_project!()
      activity = insert_activity!(project)

      corrected_id = Ecto.UUID.generate()

      {:ok, _corrected} =
        %RawMeasurement{id: corrected_id}
        |> RawMeasurement.changeset(activity.id, %{
          measured_at: ~U[2026-06-03 12:00:00.000000Z],
          source_type: "MANUAL_ENTRY",
          content_hash: "eeeeeeeeeeee" <> String.duplicate("0", 52),
          provenance: %{"operator" => "corrector"},
          values: %{"co2_kg" => 44.0}
        })
        |> Repo.insert()

      {:ok, superseded} =
        %RawMeasurement{}
        |> RawMeasurement.changeset(activity.id, %{
          measured_at: ~U[2026-06-03 11:00:00.000000Z],
          source_type: "MANUAL_ENTRY",
          content_hash: "ffffffffffff" <> String.duplicate("0", 52),
          provenance: %{"operator" => "original"},
          values: %{"co2_kg" => 40.0},
          is_superseded: true,
          superseded_by: corrected_id
        })
        |> Repo.insert()

      assert_raise Postgrex.Error, ~r/raw_measurements is append-only/i, fn ->
        Repo.query!(
          "UPDATE raw_measurements SET content_hash = 'changed' WHERE id = $1",
          [uuid_bin(superseded.id)]
        )
      end
    end
  end
end
