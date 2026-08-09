defmodule Livedata.MeasurementsTest do
  use Livedata.DataCase, async: false

  @moduletag :integration

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
end
