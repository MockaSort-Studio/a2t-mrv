defmodule Livedata.MonitoringTest do
  # Inserts raw measurements (hypertable) — must not run async.
  use Livedata.DataCase, async: false

  @moduletag :integration

  import Livedata.Fixtures

  alias Livedata.Monitoring

  test "an activity that has never been measured needs attention" do
    %{project: project, activity: activity} = portfolio_fixture()

    assert [item] = Monitoring.attention_items()
    assert item.id == activity.id
    assert item.project_name == project.name
    assert item.reason == :never_measured
    assert item.days_since_measurement == nil
  end

  test "a recently measured activity does not need attention" do
    %{activity: activity} = portfolio_fixture()
    measurement_fixture(activity.id, DateTime.utc_now())

    assert Monitoring.attention_items() == []
  end

  test "an activity measured longer ago than the threshold needs attention" do
    %{activity: activity} = portfolio_fixture()
    stale_days = Monitoring.stale_after_days() + 5
    measurement_fixture(activity.id, DateTime.add(DateTime.utc_now(), -stale_days, :day))

    assert [item] = Monitoring.attention_items()
    assert item.reason == :stale
    assert item.days_since_measurement >= Monitoring.stale_after_days()
  end

  # @req: CRCF-14 — nothing is owed outside the monitoring period.
  test "an activity whose monitoring window has not opened is excluded" do
    project = project_fixture()
    future = Date.add(Date.utc_today(), 30)

    activity_fixture(project.id, %{
      activity_period_start: future,
      monitoring_period_start: future
    })

    assert Monitoring.attention_items() == []
  end

  # @req: CRCF-14
  test "an activity whose monitoring window has closed is excluded" do
    project = project_fixture()

    activity_fixture(project.id, %{
      activity_type: "FARMING_SEQUESTRATION",
      activity_period_start: ~D[2020-01-01],
      activity_period_end: ~D[2021-01-01],
      monitoring_period_start: ~D[2019-01-01],
      monitoring_period_end: ~D[2022-01-01]
    })

    assert Monitoring.attention_items() == []
  end

  test "never-measured activities sort ahead of merely stale ones" do
    %{activity: stale} = portfolio_fixture()
    never = activity_fixture(stale.project_id)

    measurement_fixture(
      stale.id,
      DateTime.add(DateTime.utc_now(), -(Monitoring.stale_after_days() + 1), :day)
    )

    assert [first, second] = Monitoring.attention_items()
    assert first.id == never.id
    assert second.id == stale.id
  end
end
