defmodule LivedataWeb.ActivityShowLiveTest do
  # Inserts raw measurements (hypertable) — must not run async.
  use LivedataWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Livedata.Fixtures

  describe "header and timeline" do
    test "renders the activity's badges, UUID and actions", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/activities/#{activity.id}")

      assert has_element?(view, "#activity-detail", activity.name)
      assert has_element?(view, "#activity-detail", "Permanent removal")
      assert has_element?(view, "#activity-detail", "tier PERMANENT")
      # @req: CRCF-19
      assert has_element?(view, "#activity-uuid", activity.id)
      assert has_element?(view, "#activity-record-link")
      assert has_element?(view, "#activity-upload-link")
      assert has_element?(view, "#breadcrumbs")
    end

    # @req: CRCF-14 — permanent removal has no monitoring end, so no progress.
    test "an open-ended monitoring window shows no progress bar", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/activities/#{activity.id}")

      assert has_element?(view, "#monitoring-open-ended")
      refute has_element?(view, "#monitoring-progress")
    end

    # @req: CRCF-14
    test "a closed monitoring window shows elapsed days", %{conn: conn} do
      project = project_fixture()

      activity =
        activity_fixture(project.id, %{
          activity_type: "FARMING_SEQUESTRATION",
          activity_period_start: Date.add(Date.utc_today(), -100),
          activity_period_end: Date.add(Date.utc_today(), 100),
          monitoring_period_start: Date.add(Date.utc_today(), -100),
          monitoring_period_end: Date.add(Date.utc_today(), 100)
        })

      {:ok, view, _html} = live(conn, ~p"/activities/#{activity.id}")

      assert has_element?(view, "#monitoring-progress", "of 200 days elapsed")
      assert has_element?(view, "#monitoring-progress", "50%")
      refute has_element?(view, "#monitoring-open-ended")
    end
  end

  describe "measurements table" do
    test "shows the empty state when nothing has been recorded", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/activities/#{activity.id}")

      # The empty row is always in the DOM — CSS `only:` hides it when the
      # stream has rows — so the count is what actually proves emptiness.
      assert has_element?(view, "#measurements-empty")
      assert has_element?(view, "#measurements-count", "Showing 0 of 0")
    end

    test "lists a measurement with its source and values summary", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()
      m = measurement_fixture(activity.id, DateTime.utc_now(), %{"soc" => 2.5})

      {:ok, view, _html} = live(conn, ~p"/activities/#{activity.id}")

      assert has_element?(view, "#measurements-table #measurements-#{m.id}", "MANUAL_ENTRY")
      assert has_element?(view, "#measurements-#{m.id}", "soc: 2.5")
      assert has_element?(view, "#measurements-#{m.id}", "core @ 45.1, 7.6")
      assert has_element?(view, "#activity-coverage", "1")
      assert has_element?(view, "#measurements-count", "Showing 1 of 1")
    end

    # @req: CRCF-19, CRCF-22 — an audit needs the full record, not a summary.
    test "expanding a row reveals the full provenance, values and UUID", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()
      m = measurement_fixture(activity.id, DateTime.utc_now(), %{"soc" => 2.5})

      {:ok, view, _html} = live(conn, ~p"/activities/#{activity.id}")
      refute has_element?(view, "#measurement-detail-#{m.id}")

      render_click(element(view, "#toggle-#{m.id}"))

      assert has_element?(view, "#measurement-detail-#{m.id}", m.id)
      assert has_element?(view, "#measurement-detail-#{m.id}", "EPSG:4326")

      render_click(element(view, "#toggle-#{m.id}"))
      refute has_element?(view, "#measurement-detail-#{m.id}")
    end

    test "filtering by source type re-streams the table", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()
      m = measurement_fixture(activity.id, DateTime.utc_now())

      {:ok, view, _html} = live(conn, ~p"/activities/#{activity.id}")

      render_change(element(view, "#measurement-filters"), %{
        "source_type" => "REMOTE_SENSING",
        "include_superseded" => "true"
      })

      refute has_element?(view, "#measurements-#{m.id}")
      assert has_element?(view, "#measurements-count", "Showing 0 of 0")

      render_change(element(view, "#measurement-filters"), %{
        "source_type" => "MANUAL_ENTRY",
        "include_superseded" => "true"
      })

      assert has_element?(view, "#measurements-#{m.id}")
    end

    test "filtering by date range excludes measurements outside the window", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()

      past = measurement_fixture(activity.id, DateTime.add(DateTime.utc_now(), -400, :day))
      recent = measurement_fixture(activity.id, DateTime.utc_now())

      {:ok, view, _html} = live(conn, ~p"/activities/#{activity.id}")

      assert has_element?(view, "#measurements-#{past.id}")
      assert has_element?(view, "#measurements-#{recent.id}")

      render_change(element(view, "#measurement-filters"), %{
        "from" => Date.to_iso8601(Date.add(Date.utc_today(), -30)),
        "to" => Date.to_iso8601(Date.utc_today()),
        "include_superseded" => "true"
      })

      refute has_element?(view, "#measurements-#{past.id}")
      assert has_element?(view, "#measurements-#{recent.id}")
    end

    test "load more appends the next page", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()

      measurements =
        for offset <- 1..27 do
          measurement_fixture(activity.id, DateTime.add(DateTime.utc_now(), -offset, :hour))
        end

      {:ok, view, _html} = live(conn, ~p"/activities/#{activity.id}")

      assert has_element?(view, "#measurements-count", "Showing 25 of 27")
      oldest = List.last(measurements)
      refute has_element?(view, "#measurements-#{oldest.id}")

      render_click(element(view, "#load-more"))

      assert has_element?(view, "#measurements-count", "Showing 27 of 27")
      assert has_element?(view, "#measurements-#{oldest.id}")
      refute has_element?(view, "#load-more")
    end
  end

  test "raises for an unknown activity", %{conn: conn} do
    assert_raise Ecto.NoResultsError, fn ->
      live(conn, ~p"/activities/#{Ecto.UUID.generate()}")
    end
  end
end
