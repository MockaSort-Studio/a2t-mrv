defmodule LivedataWeb.AdminProjectLiveTest do
  use LivedataWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Livedata.Fixtures

  describe "AdminProjectLive" do
    setup %{conn: conn} do
      {:ok, conn: log_in_admin(conn)}
    end

    test "shows project identity, parcels, activity types, counts, and latest times", %{
      conn: conn
    } do
      %{project: project, activity: activity} =
        portfolio_fixture(project: %{name: "Audit Project", status: "MONITORING"})

      parcel_fixture(project.id, %{parcel_ref: "CAD-2", data_source: "CADASTER"})

      unmeasured =
        activity_fixture(project.id, %{
          activity_type: "PRODUCT_STORAGE",
          activity_period_end: ~D[2026-12-31],
          monitoring_period_end: ~D[2026-12-31]
        })

      measured_at = ~U[2026-07-02 10:00:00.000000Z]
      measurement_fixture(activity.id, measured_at)
      {:ok, view, _html} = live(conn, ~p"/admin/projects/#{project.id}")
      assert has_element?(view, "#admin-project-detail", "Audit Project")
      assert has_element?(view, "#admin-project-uuid", project.id)
      assert has_element?(view, "#admin-project-status", "Monitoring")
      assert has_element?(view, "#admin-project-parcels", "LPIS")
      assert has_element?(view, "#admin-project-parcels", "CAD-2")
      assert has_element?(view, "#admin-project-parcels", "CADASTER")
      assert has_element?(view, "#admin-activity-#{activity.id}", "Permanent removal")
      assert has_element?(view, "#admin-activity-#{activity.id}", "1 measurements")

      assert has_element?(
               view,
               "#admin-activity-#{activity.id} span[title='2026-07-02 10:00 UTC']"
             )

      assert has_element?(view, "#admin-activity-#{unmeasured.id}", "Product storage")
      assert has_element?(view, "#admin-activity-#{unmeasured.id}", "0 measurements")
      assert has_element?(view, "#admin-activity-#{unmeasured.id}", "never")
    end

    test "scopes the measurement table and total to the selected project", %{conn: conn} do
      %{project: project, activity: activity} = portfolio_fixture()
      own = measurement_fixture(activity.id)
      %{activity: other_activity} = portfolio_fixture()
      other = measurement_fixture(other_activity.id)
      {:ok, view, _html} = live(conn, ~p"/admin/projects/#{project.id}")
      assert has_element?(view, "#measurements-#{own.id}")
      refute has_element?(view, "#measurements-#{other.id}")
      assert has_element?(view, "#admin-measurements-count", "Showing 1 of 1")
    end

    test "opens complete pretty JSON, every audit field, and the linked parent trace", %{
      conn: conn
    } do
      %{project: project, activity: activity} = portfolio_fixture()

      provenance = %{
        "method" => "core",
        "device" => %{"calibration" => %{"lab" => "CRCF lab", "cycles" => 3}}
      }

      values = %{"soc" => 2.5, "samples" => [%{"depth_cm" => [0, 30]}]}

      %{superseded: superseded, replacement: replacement} =
        supersession_fixture(activity.id, provenance: provenance, values: values)

      {:ok, view, _html} = live(conn, ~p"/admin/projects/#{project.id}")
      assert has_element?(view, "#measurements-#{superseded.id}", "MANUAL_ENTRY")
      assert has_element?(view, "#measurements-#{superseded.id}", "soc: 2.5")
      assert has_element?(view, "#measurements-#{superseded.id}", "core")
      assert has_element?(view, "#measurements-#{superseded.id}", "superseded")
      assert has_element?(view, "#view-replacement-#{superseded.id}", "View replacement")
      refute has_element?(view, "#detail-popover")
      render_click(element(view, "#measurements-#{superseded.id}"))
      assert has_element?(view, "#detail-popover", superseded.id)
      assert has_element?(view, "#detail-content-hash", superseded.content_hash)

      assert has_element?(
               view,
               "#detail-inserted-at",
               LivedataWeb.Format.utc(superseded.inserted_at)
             )

      assert has_element?(view, "#detail-activity-id", activity.id)
      assert has_element?(view, "#detail-superseded-by", replacement.id)
      assert has_element?(view, "#detail-popover", "superseded")
      assert_pretty_json(view, "#detail-provenance", provenance)
      assert_pretty_json(view, "#detail-values", values)
      assert has_element?(view, "#measurement-trace", "Project / Activity / Measurement")
      assert has_element?(view, "#measurement-trace", project.id)
      assert has_element?(view, "#measurement-trace", activity.id)
      assert has_element?(view, "#measurement-trace", superseded.id)
      assert has_element?(view, "#measurement-trace", project.name)
      assert has_element?(view, "#measurement-trace", activity.name)
      assert has_element?(view, "#trace-project[href='/admin/projects/#{project.id}']")
      assert has_element?(view, "#trace-activity[href='/activities/#{activity.id}']")

      assert has_element?(
               view,
               "#detail-popover[role='dialog'][aria-modal='true'][aria-labelledby='detail-title'][tabindex='-1']"
             )

      assert has_element?(view, "#detail-title", "Raw measurement details")
      assert has_element?(view, "#close-detail-popover[aria-label='Close measurement details']")
      assert render(element(view, "#detail-popover")) =~ "phx-mounted"
      assert render(element(view, "#detail-popover")) =~ "max-height: calc(100dvh - 2rem)"
      assert render(element(view, "#detail-popover")) =~ "min-h-0 flex-1"

      assert render(element(view, "#close-detail-popover")) =~
               "measurement-details-#{superseded.id}"

      render_click(element(view, "#close-detail-popover"))
      refute has_element?(view, "#detail-popover")
    end

    test "provides native keyboard-focusable details actions and Escape dismissal", %{conn: conn} do
      %{project: project, activity: activity} = portfolio_fixture()
      measurement = measurement_fixture(activity.id)
      {:ok, view, _html} = live(conn, ~p"/admin/projects/#{project.id}")

      assert has_element?(
               view,
               "button#measurement-details-#{measurement.id}[type='button'][phx-click='select_measurement']"
             )

      render_click(element(view, "#measurement-details-#{measurement.id}"))
      assert has_element?(view, "#detail-popover", measurement.id)
      render_keydown(element(view, "#detail-popover"), %{"key" => "Escape"})
      refute has_element?(view, "#detail-popover")
    end

    test "navigates to an off-page cross-activity replacement without loading page two", %{
      conn: conn
    } do
      %{project: project, activity: activity} = portfolio_fixture()
      other_activity = activity_fixture(project.id, %{name: "Correcting activity"})
      measured_at = ~U[2026-08-01 00:00:00.000000Z]

      for hour <- 1..25 do
        measurement_fixture(activity.id, DateTime.add(measured_at, -hour, :hour))
      end

      %{superseded: superseded, replacement: replacement} =
        supersession_fixture(activity.id,
          replacement_activity_id: other_activity.id,
          measured_at: measured_at,
          replacement_measured_at: DateTime.add(measured_at, -48, :hour),
          replacement_values: %{"corrected" => %{"soc" => 3.5}}
        )

      {:ok, view, _html} = live(conn, ~p"/admin/projects/#{project.id}")
      assert has_element?(view, "#measurements-#{superseded.id}")
      refute has_element?(view, "#measurements-#{replacement.id}")
      assert has_element?(view, "#admin-measurements-count", "Showing 25 of 27")
      render_click(element(view, "#measurements-#{superseded.id}"))
      assert has_element?(view, "#detail-popover", superseded.id)
      render_click(element(view, "#view-replacement"))
      assert has_element?(view, "#detail-popover", replacement.id)
      assert has_element?(view, "#measurement-trace", other_activity.id)
      assert has_element?(view, "#measurement-trace", "Correcting activity")
      assert has_element?(view, "#measurement-trace", project.id)
      assert_pretty_json(view, "#detail-values", %{"corrected" => %{"soc" => 3.5}})
      refute has_element?(view, "#measurements-#{replacement.id}")
      assert has_element?(view, "#admin-measurements-count", "Showing 25 of 27")
      assert has_element?(view, "#load-more")

      assert render(element(view, "#close-detail-popover")) =~
               "measurement-details-#{superseded.id}"
    end

    test "bounds list queries to 25 rows and appends page two without a count or duplicate collection",
         %{conn: conn} do
      %{project: project, activity: activity} = portfolio_fixture()

      measurements =
        for hour <- 1..27 do
          measurement_fixture(activity.id, DateTime.add(~U[2026-08-01 00:00:00Z], hour, :hour))
        end

      capture_queries(:admin_query, Ecto.UUID.dump!(project.id))
      {:ok, view, _html} = live(conn, ~p"/admin/projects/#{project.id}")
      initial_lists = measurement_list_queries(drain_queries(:admin_query))
      assert initial_lists != []

      assert Enum.all?(initial_lists, fn %{params: params, result: result} ->
               25 in params and match?({:ok, %{num_rows: 25}}, result)
             end)

      assert_bounded_measurement_assigns(view, 25, 27)
      assert has_element?(view, "#admin-measurements-count", "Showing 25 of 27")
      oldest = List.first(measurements)
      refute has_element?(view, "#measurements-#{oldest.id}")
      render_click(element(view, "#load-more"))
      load_more_queries = measurement_queries(drain_queries(:admin_query))

      assert length(load_more_queries) == 1
      refute Enum.any?(load_more_queries, &count_query?/1)

      assert [%{params: next_params, result: {:ok, %{num_rows: 2}}}] =
               measurement_list_queries(load_more_queries)

      assert 25 in next_params
      assert_bounded_measurement_assigns(view, 27, 27)
      assert has_element?(view, "#admin-measurements-count", "Showing 27 of 27")

      Enum.each(measurements, fn measurement ->
        assert has_element?(view, "#measurements-#{measurement.id}")
      end)

      refute has_element?(view, "#load-more")
      render_click(element(view, "#measurements-#{oldest.id}"))
      assert_bounded_measurement_assigns(view, 27, 27)
    end

    test "raises for an unknown project", %{conn: conn} do
      assert_raise Ecto.NoResultsError, fn ->
        live(conn, ~p"/admin/projects/#{Ecto.UUID.generate()}")
      end
    end

    test "requires an admin user" do
      %{activity: activity} = portfolio_fixture()
      non_admin = log_in_user(build_conn())

      assert {:error, {:live_redirect, %{to: "/"}}} =
               live(non_admin, ~p"/admin/projects/#{activity.project_id}")

      assert {:error, {:live_redirect, %{to: "/login"}}} =
               live(build_conn(), ~p"/admin/projects/#{activity.project_id}")
    end

    # GHSA-v4p7-3pm2-wq6c: isolated mounting has no router live_session and an
    # empty route-param map, matching the sensitive part of a location-less root
    # join. Module-level auth must halt before the required-ID mount can return a
    # view capable of accepting events.
    test "rejects a non-admin isolated root join before mount or events" do
      result = live_isolated(log_in_user(build_conn()), LivedataWeb.AdminProjectLive, params: %{})

      assert {:error, {:live_redirect, %{to: "/"}}} = result
    end
  end

  defp assert_pretty_json(view, selector, term) do
    escaped =
      term
      |> Jason.encode!(pretty: true)
      |> Phoenix.HTML.html_escape()
      |> Phoenix.HTML.safe_to_string()

    assert view |> element(selector) |> render() =~ escaped
  end

  defp assert_bounded_measurement_assigns(view, loaded_count, total) do
    assigns = socket_assigns(view)
    assert assigns.loaded_count == loaded_count
    assert assigns.total == total
    refute Map.has_key?(assigns, :loaded)

    duplicate_collections =
      for {key, value} <- assigns,
          is_list(value),
          Enum.any?(value, &match?(%{content_hash: _, activity_id: _}, &1)),
          do: key

    assert duplicate_collections == []
  end

  defp capture_queries(tag, uuid) do
    test_pid = self()
    handler_id = "#{tag}-#{System.unique_integer([:positive])}"

    :telemetry.attach(
      handler_id,
      [:livedata, :repo, :query],
      fn _event, _measurements, metadata, _config ->
        if uuid in metadata.params do
          send(test_pid, {tag, metadata.query, metadata.params, metadata.result})
        end
      end,
      nil
    )

    on_exit(fn -> :telemetry.detach(handler_id) end)
  end

  defp socket_assigns(view) do
    view.pid
    |> :sys.get_state()
    |> then(fn state -> Map.get(state, :socket, state) end)
    |> Map.fetch!(:assigns)
  end

  defp drain_queries(tag, queries \\ []) do
    receive do
      {^tag, query, params, result} ->
        drain_queries(tag, [%{query: query, params: params, result: result} | queries])
    after
      0 -> Enum.reverse(queries)
    end
  end

  defp measurement_queries(queries) do
    Enum.filter(queries, &String.contains?(&1.query, ~s(FROM "raw_measurements")))
  end

  defp measurement_list_queries(queries) do
    queries
    |> measurement_queries()
    |> Enum.filter(&String.starts_with?(&1.query, ~s(SELECT r0."id")))
  end

  defp count_query?(%{query: query}), do: String.contains?(query, "SELECT count(")
end
