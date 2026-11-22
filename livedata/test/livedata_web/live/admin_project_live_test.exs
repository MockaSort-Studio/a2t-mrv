defmodule LivedataWeb.AdminProjectLiveTest do
  use LivedataWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Livedata.Fixtures

  describe "ActivityShowLive resource baseline" do
    setup %{conn: conn} do
      {:ok, conn: log_in_user(conn)}
    end

    test "27 records use 25-row pages, a list and count per load, and retain all loaded rows", %{
      conn: conn
    } do
      %{activity: activity} = portfolio_fixture()

      for offset <- 1..27 do
        measurement_fixture(activity.id, DateTime.add(DateTime.utc_now(), -offset, :hour))
      end

      test_pid = self()
      activity_uuid = Ecto.UUID.dump!(activity.id)
      handler_id = "activity-pagination-baseline-#{System.unique_integer([:positive])}"

      :telemetry.attach(
        handler_id,
        [:livedata, :repo, :query],
        fn _event, _measurements, metadata, _config ->
          if activity_uuid in metadata.params do
            send(test_pid, {:baseline_query, metadata.query, metadata.params, metadata.result})
          end
        end,
        nil
      )

      on_exit(fn -> :telemetry.detach(handler_id) end)

      {:ok, view, _html} = live(conn, ~p"/activities/#{activity.id}")
      initial_queries = drain_baseline_queries()
      initial_lists = measurement_list_queries(initial_queries)

      assert initial_lists != []

      assert Enum.all?(initial_lists, fn %{params: params, result: result} ->
               25 in params and match?({:ok, %{num_rows: 25}}, result)
             end)

      assert length(socket_assigns(view).loaded) == 25

      render_click(element(view, "#load-more"))
      load_more_queries = measurement_queries(drain_baseline_queries())
      load_more_lists = measurement_list_queries(load_more_queries)
      load_more_counts = Enum.filter(load_more_queries, &count_query?/1)

      assert length(load_more_queries) == 2
      assert length(load_more_counts) == 1
      assert [%{params: next_params, result: {:ok, %{num_rows: 2}}}] = load_more_lists
      assert 25 in next_params
      refute Enum.any?(load_more_lists, &count_query?/1)

      loaded = socket_assigns(view).loaded
      assert length(loaded) == 27
      assert loaded |> Enum.map(& &1.id) |> Enum.uniq() |> length() == 27
    end
  end

  defp socket_assigns(view) do
    view.pid
    |> :sys.get_state()
    |> then(fn state -> Map.get(state, :socket, state) end)
    |> Map.fetch!(:assigns)
  end

  defp drain_baseline_queries(queries \\ []) do
    receive do
      {:baseline_query, query, params, result} ->
        drain_baseline_queries([%{query: query, params: params, result: result} | queries])
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
