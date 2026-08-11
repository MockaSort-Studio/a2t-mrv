defmodule Livedata.MeasurementsTest do
  use Livedata.DataCase, async: false

  @moduletag :integration

  alias Livedata.Fixtures
  alias Livedata.Measurements
  alias Livedata.Measurements.RawMeasurement
  alias Livedata.Projects.{Project, Activity}

  # Inserts a Project + Activity (satisfying #63 period rules) and returns the activity id.
  defp activity_id! do
    project =
      %Project{}
      |> Project.changeset(%{
        name: "P",
        status: "DRAFT",
        commissioned_at: DateTime.utc_now()
      })
      |> Repo.insert!()

    activity =
      %Activity{}
      |> Activity.changeset(project.id, %{
        name: "A",
        activity_type: "PERMANENT_REMOVAL",
        status: "REGISTERED",
        activity_period_start: ~D[2026-01-01],
        monitoring_period_start: ~D[2025-12-01]
      })
      |> Repo.insert!()

    activity.id
  end

  defp valid_attrs(overrides) do
    Map.merge(
      %{
        "activity_id" => activity_id!(),
        "measured_at" => "2026-07-01T10:00:00Z",
        "provenance_json" =>
          ~s({"method":"core","latitude":45.1,"longitude":7.6,"crs":"EPSG:4326"}),
        "values_json" => ~s({"soc":2.3,"unit":"pct"})
      },
      overrides
    )
  end

  test "creates a raw measurement with MANUAL_ENTRY source and a content hash" do
    assert {:ok, %RawMeasurement{} = rm} = Measurements.create_raw_measurement(valid_attrs(%{}))
    assert rm.source_type == "MANUAL_ENTRY"
    assert is_binary(rm.content_hash) and byte_size(rm.content_hash) == 64
    assert rm.values["soc"] == 2.3
  end

  test "content_hash is deterministic and key-order independent" do
    aid = Ecto.UUID.generate()
    at = ~U[2026-07-01 10:00:00.000000Z]
    h1 = Measurements.content_hash("MANUAL_ENTRY", aid, at, %{"a" => 1, "b" => 2})
    h2 = Measurements.content_hash("MANUAL_ENTRY", aid, at, %{"b" => 2, "a" => 1})
    h3 = Measurements.content_hash("MANUAL_ENTRY", aid, at, %{"a" => 9, "b" => 2})
    assert h1 == h2
    assert h1 != h3
  end

  test "resubmitting the identical measurement is rejected as duplicate" do
    attrs = valid_attrs(%{})
    assert {:ok, _} = Measurements.create_raw_measurement(attrs)
    assert {:error, :duplicate} = Measurements.create_raw_measurement(attrs)
  end

  test "missing a required provenance key is rejected" do
    attrs = valid_attrs(%{"provenance_json" => ~s({"method":"core"})})
    assert {:error, %Ecto.Changeset{}} = Measurements.create_raw_measurement(attrs)
  end

  test "invalid values JSON is rejected" do
    attrs = valid_attrs(%{"values_json" => "{bad"})
    assert {:error, %Ecto.Changeset{}} = Measurements.create_raw_measurement(attrs)
  end

  test "nonexistent activity_id is rejected by the FK" do
    attrs = valid_attrs(%{"activity_id" => Ecto.UUID.generate()})
    assert {:error, %Ecto.Changeset{}} = Measurements.create_raw_measurement(attrs)
  end

  describe "list_recent/1" do
    test "returns [] when nothing has been submitted" do
      assert Measurements.list_recent() == []
    end

    # @req: CRCF-22 — a measurement is traceable to its activity and project.
    test "carries the activity and project of each measurement, newest first" do
      %{project: project, activity: activity} = Fixtures.portfolio_fixture()
      older = DateTime.add(DateTime.utc_now(), -2, :day)
      Fixtures.measurement_fixture(activity.id, older)
      newest = Fixtures.measurement_fixture(activity.id, DateTime.utc_now())

      assert [first, _second] = Measurements.list_recent()
      assert first.id == newest.id
      assert first.activity_name == activity.name
      assert first.project_name == project.name
      assert first.source_type == "MANUAL_ENTRY"
    end

    test "honours the limit" do
      %{activity: activity} = Fixtures.portfolio_fixture()

      for offset <- 1..3 do
        Fixtures.measurement_fixture(
          activity.id,
          DateTime.add(DateTime.utc_now(), -offset, :hour)
        )
      end

      assert length(Measurements.list_recent(2)) == 2
    end
  end

  describe "count_since/1" do
    test "counts only measurements at or after the cutoff" do
      %{activity: activity} = Fixtures.portfolio_fixture()
      Fixtures.measurement_fixture(activity.id, DateTime.add(DateTime.utc_now(), -40, :day))
      Fixtures.measurement_fixture(activity.id, DateTime.utc_now())

      assert Measurements.count_since(DateTime.add(DateTime.utc_now(), -30, :day)) == 1
      assert Measurements.count_since(DateTime.add(DateTime.utc_now(), -60, :day)) == 2
    end
  end
end
