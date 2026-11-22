defmodule Livedata.MeasurementsTest do
  use Livedata.DataCase, async: true

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
        "method" => "core",
        "latitude" => "45.1",
        "longitude" => "7.6",
        "crs" => "EPSG:4326",
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

  # @req: CRCF-16 — coordinates are structurally required, not hoped for.
  test "missing provenance coordinates are rejected" do
    attrs = valid_attrs(%{"latitude" => "", "longitude" => ""})
    assert {:error, %Ecto.Changeset{}} = Measurements.create_raw_measurement(attrs)
  end

  test "the persisted provenance always carries the required keys" do
    assert {:ok, rm} = Measurements.create_raw_measurement(valid_attrs(%{}))
    assert rm.provenance["method"] == "core"
    assert rm.provenance["latitude"] == 45.1
    assert rm.provenance["crs"] == "EPSG:4326"
  end

  # @req: CRCF-28 — provenance is excluded from the hash by design.
  test "a reading resubmitted from different coordinates is still a duplicate" do
    attrs = valid_attrs(%{})
    assert {:ok, _} = Measurements.create_raw_measurement(attrs)

    moved = Map.merge(attrs, %{"latitude" => "10.0", "longitude" => "20.0"})
    assert {:error, :duplicate} = Measurements.create_raw_measurement(moved)
  end

  test "invalid values JSON is rejected" do
    attrs = valid_attrs(%{"values_json" => "{bad"})
    assert {:error, %Ecto.Changeset{}} = Measurements.create_raw_measurement(attrs)
  end

  test "nonexistent activity_id is rejected by the FK" do
    attrs = valid_attrs(%{"activity_id" => Ecto.UUID.generate()})
    assert {:error, %Ecto.Changeset{}} = Measurements.create_raw_measurement(attrs)
  end

  describe "deletion integrity" do
    # @req: CRCF-21 — measured activities cannot be deleted into orphaned evidence.
    test "deleting a measured activity fails and leaves the full chain intact" do
      %{project: project, activity: activity} = Fixtures.portfolio_fixture()
      measurement = Fixtures.measurement_fixture(activity.id)
      project_id = project.id
      activity_id = activity.id
      measurement_id = measurement.id

      assert_raise Ecto.ConstraintError, ~r/raw_measurements_activity_id_fkey/, fn ->
        Repo.delete!(activity)
      end

      assert %Project{id: ^project_id} = Repo.get(Project, project_id)

      assert %Activity{id: ^activity_id, project_id: ^project_id} =
               Repo.get(Activity, activity_id)

      assert %RawMeasurement{id: ^measurement_id, activity_id: ^activity_id} =
               Repo.get(RawMeasurement, measurement_id)
    end

    # @req: CRCF-21 — the activity cascade cannot bypass measurement protection.
    test "deleting a project containing measurements fails and leaves the full chain intact" do
      %{project: project, activity: activity} = Fixtures.portfolio_fixture()
      measurement = Fixtures.measurement_fixture(activity.id)
      project_id = project.id
      activity_id = activity.id
      measurement_id = measurement.id

      assert_raise Ecto.ConstraintError, ~r/raw_measurements_activity_id_fkey/, fn ->
        Repo.delete!(project)
      end

      assert %Project{id: ^project_id} = Repo.get(Project, project_id)

      assert %Activity{id: ^activity_id, project_id: ^project_id} =
               Repo.get(Activity, activity_id)

      assert %RawMeasurement{id: ^measurement_id, activity_id: ^activity_id} =
               Repo.get(RawMeasurement, measurement_id)
    end

    test "deleting a project still cascades through unmeasured activities" do
      %{project: project, activity: activity} = Fixtures.portfolio_fixture()
      other_activity = Fixtures.activity_fixture(project.id)

      assert Repo.delete!(project)
      assert Repo.get(Project, project.id) == nil
      assert Repo.get(Activity, activity.id) == nil
      assert Repo.get(Activity, other_activity.id) == nil
    end
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

  describe "raw measurement browsing" do
    test "lists complete records by project or activity with parent context" do
      %{project: project, activity: activity} = Fixtures.portfolio_fixture()
      other_activity = Fixtures.activity_fixture(project.id)
      older_at = ~U[2026-07-01 10:00:00.000000Z]
      newer_at = ~U[2026-07-02 10:00:00.000000Z]
      older = Fixtures.measurement_fixture(activity.id, older_at, %{"soc" => 2.1})
      newer = Fixtures.measurement_fixture(other_activity.id, newer_at, %{"soc" => 2.2})

      assert [first, second] = Measurements.list_raw_measurements({:project, project.id})
      assert_complete_raw_measurement(first, newer)
      assert_complete_raw_measurement(second, older)
      assert first.activity_name == other_activity.name
      assert first.project_id == project.id
      assert first.project_name == project.name
      assert second.activity_name == activity.name

      assert [activity_row] = Measurements.list_raw_measurements({:activity, activity.id})
      assert_complete_raw_measurement(activity_row, older)
      assert Measurements.count_raw_measurements({:project, project.id}) == 2
      assert Measurements.count_raw_measurements({:activity, activity.id}) == 1
    end

    test "project and activity scopes isolate other projects and activities" do
      %{project: project, activity: activity} = Fixtures.portfolio_fixture()
      other_activity = Fixtures.activity_fixture(project.id)
      %{project: other_project, activity: other_project_activity} = Fixtures.portfolio_fixture()
      own = Fixtures.measurement_fixture(activity.id)
      Fixtures.measurement_fixture(other_activity.id)
      Fixtures.measurement_fixture(other_project_activity.id)

      assert Enum.map(Measurements.list_raw_measurements({:activity, activity.id}), & &1.id) == [
               own.id
             ]

      project_rows = Measurements.list_raw_measurements({:project, project.id})
      assert length(project_rows) == 2
      assert Enum.all?(project_rows, &(&1.project_id == project.id))
      assert Measurements.count_raw_measurements({:project, other_project.id}) == 1
      assert Measurements.count_raw_measurements({:activity, other_activity.id}) == 1
    end

    test "orders equal measurement timestamps by id descending" do
      %{activity: activity} = Fixtures.portfolio_fixture()
      measured_at = ~U[2026-07-01 10:00:00.000000Z]
      first = Fixtures.measurement_fixture(activity.id, measured_at)
      second = Fixtures.measurement_fixture(activity.id, measured_at)
      expected_ids = Enum.sort_by([first, second], & &1.id, :desc) |> Enum.map(& &1.id)

      assert expected_ids ==
               Measurements.list_raw_measurements({:activity, activity.id})
               |> Enum.map(& &1.id)
    end

    test "paginates 27 measurements as exactly 25 and 2 with no overlap or omissions" do
      %{project: project, activity: activity} = Fixtures.portfolio_fixture()

      measurements =
        for offset <- 1..27 do
          Fixtures.measurement_fixture(
            activity.id,
            DateTime.add(~U[2026-07-01 10:00:00.000000Z], offset, :hour)
          )
        end

      first_page = Measurements.list_raw_measurements({:project, project.id})

      second_page =
        Measurements.list_raw_measurements({:project, project.id}, limit: 25, offset: 25)

      assert length(first_page) == 25
      assert length(second_page) == 2
      paged_ids = Enum.map(first_page ++ second_page, & &1.id)
      assert paged_ids == measurements |> Enum.reverse() |> Enum.map(& &1.id)
      assert length(Enum.uniq(paged_ids)) == 27
      assert Enum.sort(paged_ids) == measurements |> Enum.map(& &1.id) |> Enum.sort()
      assert Measurements.count_raw_measurements({:project, project.id}) == 27
    end

    test "resolves every measurement with complete detail and its actual parent chain" do
      %{project: project, activity: activity} = Fixtures.portfolio_fixture()
      other_activity = Fixtures.activity_fixture(project.id)
      %{project: other_project, activity: other_project_activity} = Fixtures.portfolio_fixture()
      own = Fixtures.measurement_fixture(activity.id)
      other = Fixtures.measurement_fixture(other_project_activity.id)

      %{superseded: superseded, replacement: replacement} =
        Fixtures.supersession_fixture(other_activity.id,
          replacement_activity_id: other_project_activity.id
        )

      for measurement <- [own, other, superseded, replacement] do
        detail = Measurements.get_raw_measurement_with_context!(measurement.id)
        assert_complete_raw_measurement(detail, measurement)
        assert detail.activity_id == measurement.activity_id

        expected_activity =
          Enum.find(
            [activity, other_activity, other_project_activity],
            &(&1.id == detail.activity_id)
          )

        expected_project =
          if expected_activity.project_id == project.id, do: project, else: other_project

        assert detail.activity_name == expected_activity.name
        assert detail.project_id == expected_project.id
        assert detail.project_name == expected_project.name
      end

      assert_raise Ecto.NoResultsError, fn ->
        Measurements.get_raw_measurement_with_context!(Ecto.UUID.generate())
      end
    end
  end

  describe "list_for_activity/2" do
    test "returns only that activity's measurements, newest first" do
      %{project: project, activity: activity} = Fixtures.portfolio_fixture()
      other = Fixtures.activity_fixture(project.id)

      older =
        Fixtures.measurement_fixture(activity.id, DateTime.add(DateTime.utc_now(), -1, :day))

      newer = Fixtures.measurement_fixture(activity.id, DateTime.utc_now())
      Fixtures.measurement_fixture(other.id, DateTime.utc_now())

      assert [first, second] = Measurements.list_for_activity(activity.id)
      assert first.id == newer.id
      assert second.id == older.id
    end

    test "filters by source type" do
      %{activity: activity} = Fixtures.portfolio_fixture()
      Fixtures.measurement_fixture(activity.id)

      assert Measurements.list_for_activity(activity.id, source_type: "MANUAL_ENTRY") != []
      assert Measurements.list_for_activity(activity.id, source_type: "MODEL_OUTPUT") == []
      # A blank filter means "all sources", not "no sources".
      assert Measurements.list_for_activity(activity.id, source_type: "") != []
    end

    test "filters by measurement time" do
      %{activity: activity} = Fixtures.portfolio_fixture()
      Fixtures.measurement_fixture(activity.id, DateTime.add(DateTime.utc_now(), -10, :day))
      recent = Fixtures.measurement_fixture(activity.id, DateTime.utc_now())

      cutoff = DateTime.add(DateTime.utc_now(), -1, :day)
      assert [only] = Measurements.list_for_activity(activity.id, from: cutoff)
      assert only.id == recent.id
      assert Measurements.list_for_activity(activity.id, to: cutoff) |> length() == 1
    end

    test "pages with limit and offset" do
      %{activity: activity} = Fixtures.portfolio_fixture()

      for offset <- 1..3 do
        Fixtures.measurement_fixture(
          activity.id,
          DateTime.add(DateTime.utc_now(), -offset, :hour)
        )
      end

      assert length(Measurements.list_for_activity(activity.id, limit: 2)) == 2
      assert length(Measurements.list_for_activity(activity.id, limit: 2, offset: 2)) == 1
    end

    test "count_for_activity/2 honours the same filters" do
      %{activity: activity} = Fixtures.portfolio_fixture()
      Fixtures.measurement_fixture(activity.id)

      assert Measurements.count_for_activity(activity.id) == 1
      assert Measurements.count_for_activity(activity.id, source_type: "MODEL_OUTPUT") == 0
    end
  end

  describe "coverage_for_activity/1" do
    test "reports zero and no span for an unmeasured activity" do
      %{activity: activity} = Fixtures.portfolio_fixture()

      assert %{count: 0, first_measured_at: nil, last_measured_at: nil} =
               Measurements.coverage_for_activity(activity.id)
    end

    test "reports the count and the measured span" do
      %{activity: activity} = Fixtures.portfolio_fixture()

      first =
        Fixtures.measurement_fixture(activity.id, DateTime.add(DateTime.utc_now(), -5, :day))

      last = Fixtures.measurement_fixture(activity.id, DateTime.utc_now())

      coverage = Measurements.coverage_for_activity(activity.id)

      assert coverage.count == 2
      assert DateTime.compare(coverage.first_measured_at, first.measured_at) == :eq
      assert DateTime.compare(coverage.last_measured_at, last.measured_at) == :eq
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

  defp assert_complete_raw_measurement(actual, expected) do
    fields = [
      :id,
      :activity_id,
      :measured_at,
      :source_type,
      :content_hash,
      :provenance,
      :values,
      :is_superseded,
      :superseded_by,
      :inserted_at
    ]

    assert Map.take(actual, fields) == Map.take(expected, fields)
  end
end
