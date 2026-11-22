defmodule LivedataWeb.AdminProjectLive do
  @moduledoc """
  Read-only, project-scoped access to raw evidence and its complete parent
  trace. Pagination is bounded by the stream; selecting any record, including
  an off-page replacement, goes back through the Measurements context.
  """
  use LivedataWeb, :live_view
  on_mount {LivedataWeb.UserAuth, :require_admin_user}

  alias Livedata.Measurements
  alias Livedata.ProjectParcels
  alias Livedata.Projects
  alias LivedataWeb.Format

  @page_size 25

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    project = Projects.get_project!(id)
    scope = {:project, project.id}
    page = Measurements.list_raw_measurements(scope, limit: @page_size, offset: 0)
    total = Measurements.count_raw_measurements(scope)

    {:ok,
     socket
     |> assign(:page_title, project.name)
     |> assign(:project, project)
     |> assign(:parcels, ProjectParcels.list_parcels_for_project(project.id))
     |> assign(:activities, Projects.list_activities_with_stats(project_id: project.id))
     |> assign(:loaded_count, length(page))
     |> assign(:total, total)
     |> assign(:selected_measurement, nil)
     |> stream(:measurements, page, reset: true)}
  end

  @impl true
  def handle_event("load_more", _params, socket) do
    page =
      Measurements.list_raw_measurements(
        {:project, socket.assigns.project.id},
        limit: @page_size,
        offset: socket.assigns.loaded_count
      )

    {:noreply,
     socket
     |> assign(:loaded_count, socket.assigns.loaded_count + length(page))
     |> stream(:measurements, page)}
  end

  def handle_event("select_measurement", %{"id" => id}, socket) do
    {:noreply, select_measurement(socket, id, id)}
  end

  def handle_event("view_replacement", %{"id" => id} = params, socket) do
    selected = socket.assigns.selected_measurement
    origin_id = params["origin-id"] || (selected && selected.detail_origin_id) || id
    {:noreply, select_measurement(socket, id, origin_id)}
  end

  def handle_event("close_measurement_detail", _params, socket) do
    {:noreply, assign(socket, :selected_measurement, nil)}
  end

  defp select_measurement(socket, id, origin_id) do
    measurement =
      id
      |> Measurements.get_raw_measurement_with_context!()
      |> Map.put(:detail_origin_id, origin_id)

    assign(socket, :selected_measurement, measurement)
  end

  defp close_detail_js(measurement) do
    "close_measurement_detail"
    |> JS.push()
    |> JS.focus(to: "#measurement-details-#{measurement.detail_origin_id}")
  end

  defp provenance_summary(%{provenance: nil}), do: "—"

  defp provenance_summary(%{provenance: provenance}) do
    method = provenance["method"] || "unknown method"
    lat = provenance["latitude"]
    lon = provenance["longitude"]

    if lat && lon, do: "#{method} @ #{lat}, #{lon}", else: method
  end

  defp pretty_json(nil), do: "null"
  defp pretty_json(term), do: Jason.encode!(term, pretty: true)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} max_width="max-w-7xl">
      <.modal
        id="detail-popover"
        show={!!@selected_measurement}
        on_cancel={@selected_measurement && close_detail_js(@selected_measurement)}
        max_width="max-w-2xl"
        role="dialog"
        aria-modal="true"
        aria-labelledby="detail-title"
        tabindex="-1"
        style="height: min(90dvh, 780px); max-height: calc(100dvh - 2rem)"
        phx-mounted={JS.focus(to: "#detail-popover")}
        phx-window-keydown={@selected_measurement && close_detail_js(@selected_measurement)}
        phx-key="Escape"
      >
        <h2 id="detail-title" class="sr-only">Raw measurement details</h2>
        <div class="flex shrink-0 items-center justify-between border-b border-base-300 px-5 py-4">
          <div>
            <p class="font-mono text-xs text-base-content/40">
              {@selected_measurement && @selected_measurement.id}
            </p>
            <p class="mt-0.5 text-sm font-semibold">
              {@selected_measurement && Format.utc(@selected_measurement.measured_at)}
            </p>
          </div>
          <button
            id="close-detail-popover"
            type="button"
            aria-label="Close measurement details"
            phx-click={@selected_measurement && close_detail_js(@selected_measurement)}
            class="rounded-md p-1 text-base-content/50 transition-colors hover:bg-base-200 hover:text-base-content"
          >
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </div>
        <div
          :if={@selected_measurement}
          class="min-h-0 flex-1 space-y-4 overflow-y-auto px-5 py-4"
        >
          <div class="flex items-center gap-2">
            <span class="rounded bg-base-200 px-2 py-0.5 text-xs font-medium text-base-content/60">
              {@selected_measurement.source_type}
            </span>
            <span class="rounded bg-base-200 px-2 py-0.5 text-xs font-medium text-base-content/60">
              {if @selected_measurement.is_superseded, do: "superseded", else: "current"}
            </span>
          </div>
          <dl class="grid gap-3 text-xs sm:grid-cols-2">
            <div :for={
              {label, dom_id, value} <- [
                {"Content hash", "detail-content-hash", @selected_measurement.content_hash},
                {"Inserted at", "detail-inserted-at", Format.utc(@selected_measurement.inserted_at)},
                {"Activity UUID", "detail-activity-id", @selected_measurement.activity_id},
                {"Superseded by", "detail-superseded-by", @selected_measurement.superseded_by || "—"}
              ]
            }>
              <dt class="font-medium uppercase tracking-wide text-base-content/50">{label}</dt>
              <dd id={dom_id} class="mt-1 break-all font-mono">{value}</dd>
            </div>
          </dl>
          <nav id="measurement-trace" aria-label="Measurement parent trace" class="space-y-1 text-xs">
            <p class="font-medium uppercase tracking-wide text-base-content/50">
              Project / Activity / Measurement
            </p>
            <p>
              Project:
              <.link
                id="trace-project"
                navigate={~p"/admin/projects/#{@selected_measurement.project_id}"}
                class="font-medium hover:underline"
              >
                {@selected_measurement.project_name}
              </.link>
              <span class="ml-1 font-mono text-base-content/50">
                {@selected_measurement.project_id}
              </span>
            </p>
            <p>
              Activity:
              <.link
                id="trace-activity"
                navigate={~p"/activities/#{@selected_measurement.activity_id}"}
                class="font-medium hover:underline"
              >
                {@selected_measurement.activity_name}
              </.link>
              <span class="ml-1 font-mono text-base-content/50">
                {@selected_measurement.activity_id}
              </span>
            </p>
            <p>Measurement: <span class="font-mono">{@selected_measurement.id}</span></p>
          </nav>
          <div>
            <p class="mb-1.5 text-xs font-medium uppercase tracking-wide text-base-content/50">
              Provenance
            </p>
            <pre
              id="detail-provenance"
              phx-no-curly-interpolation
              class="overflow-x-auto rounded-lg bg-base-200 p-3 text-xs text-base-content/80"
            ><%= pretty_json(@selected_measurement.provenance) %></pre>
          </div>
          <div>
            <p class="mb-1.5 text-xs font-medium uppercase tracking-wide text-base-content/50">
              Values
            </p>
            <pre
              id="detail-values"
              phx-no-curly-interpolation
              class="overflow-x-auto rounded-lg bg-base-200 p-3 text-xs text-base-content/80"
            ><%= pretty_json(@selected_measurement.values) %></pre>
          </div>
          <button
            :if={@selected_measurement.is_superseded}
            id="view-replacement"
            type="button"
            phx-click={JS.push("view_replacement") |> JS.focus(to: "#detail-popover")}
            phx-value-id={@selected_measurement.superseded_by}
            class="rounded-md border border-base-300 px-3 py-1.5 text-sm font-semibold transition-colors hover:bg-base-200"
          >
            View replacement
          </button>
        </div>
      </.modal>
      <:breadcrumbs>
        <Layouts.crumb navigate={~p"/admin/projects"}>Projects</Layouts.crumb>
        <Layouts.crumb>{@project.name}</Layouts.crumb>
      </:breadcrumbs>
      <div id="admin-project-detail" class="space-y-6">
        <header>
          <div class="flex items-center gap-2">
            <h1 class="text-2xl font-semibold">{@project.name}</h1>
            <span
              id="admin-project-status"
              class="rounded-full bg-base-200 px-2 py-0.5 text-xs font-medium text-base-content/70"
            >
              {String.capitalize(@project.status)}
            </span>
          </div>
          <p id="admin-project-uuid" class="mt-1 font-mono text-xs text-base-content/50">
            {@project.id}
          </p>
        </header>
        <div class="grid gap-4 lg:grid-cols-2">
          <section>
            <h2 class="mb-2 text-lg font-medium">Parcels</h2>
            <ul
              id="admin-project-parcels"
              class="divide-y divide-base-300 rounded-lg border border-base-300"
            >
              <li :if={@parcels == []} class="px-4 py-4 text-sm text-base-content/60">
                No parcels recorded.
              </li>
              <li :for={parcel <- @parcels} class="px-4 py-3 text-sm">
                <span class="font-medium">{parcel.parcel_ref}</span>
                <span class="ml-2 text-base-content/60">{parcel.data_source}</span>
              </li>
            </ul>
          </section>
          <section>
            <h2 class="mb-2 text-lg font-medium">Activities</h2>
            <ul
              id="admin-project-activities"
              class="divide-y divide-base-300 rounded-lg border border-base-300"
            >
              <li :if={@activities == []} class="px-4 py-4 text-sm text-base-content/60">
                No activities recorded.
              </li>
              <li
                :for={activity <- @activities}
                id={"admin-activity-#{activity.id}"}
                class="px-4 py-3"
              >
                <div class="flex items-center justify-between gap-2">
                  <span class="font-medium">{activity.name}</span>
                  <span class="text-xs text-base-content/60">
                    {Format.activity_type(activity.activity_type)}
                  </span>
                </div>
                <p class="mt-1 text-xs text-base-content/50">
                  {activity.measurement_count} measurements · latest
                  <span title={Format.utc(activity.last_measured_at)}>
                    {Format.relative_time(activity.last_measured_at)}
                  </span>
                </p>
              </li>
            </ul>
          </section>
        </div>
        <section class="space-y-3">
          <h2 class="text-lg font-medium">Raw measurements</h2>
          <div class="overflow-x-auto rounded-lg border border-base-300">
            <table class="w-full text-sm">
              <thead class="text-left text-base-content/60">
                <tr class="border-b border-base-300">
                  <th class="px-4 py-2 font-medium">Measured at</th>
                  <th class="px-4 py-2 font-medium">Activity</th>
                  <th class="px-4 py-2 font-medium">Source</th>
                  <th class="px-4 py-2 font-medium">Values</th>
                  <th class="px-4 py-2 font-medium">Provenance</th>
                  <th class="px-4 py-2 font-medium">Status</th>
                  <th class="px-4 py-2 font-medium">Actions</th>
                </tr>
              </thead>
              <tbody
                id="admin-measurements-table"
                phx-update="stream"
                class="divide-y divide-base-300"
              >
                <tr id="admin-measurements-empty" class="hidden only:table-row">
                  <td colspan="7" class="px-4 py-6 text-center text-base-content/60">
                    No measurements recorded for this project.
                  </td>
                </tr>
                <tr
                  :for={{dom_id, m} <- @streams.measurements}
                  id={dom_id}
                  phx-click="select_measurement"
                  phx-value-id={m.id}
                  class="cursor-pointer align-top transition-colors hover:bg-base-200/50"
                >
                  <td class="px-4 py-2 whitespace-nowrap">{Format.utc(m.measured_at)}</td>
                  <td class="px-4 py-2">{m.activity_name}</td>
                  <td class="px-4 py-2">{m.source_type}</td>
                  <td class="px-4 py-2 text-base-content/70">{Format.values_summary(m.values)}</td>
                  <td class="px-4 py-2 text-base-content/70">{provenance_summary(m)}</td>
                  <td class="px-4 py-2">
                    <span class={[
                      "rounded px-1.5 py-0.5 text-xs font-medium",
                      if(m.is_superseded,
                        do: "bg-amber-100 text-amber-800",
                        else: "bg-base-200 text-base-content/60"
                      )
                    ]}>
                      {if m.is_superseded, do: "superseded", else: "current"}
                    </span>
                    <button
                      :if={m.is_superseded}
                      id={"view-replacement-#{m.id}"}
                      type="button"
                      phx-click="view_replacement"
                      phx-value-id={m.superseded_by}
                      phx-value-origin-id={m.id}
                      class="ml-2 font-semibold hover:underline"
                    >
                      View replacement
                    </button>
                  </td>
                  <td class="px-4 py-2">
                    <button
                      id={"measurement-details-#{m.id}"}
                      type="button"
                      aria-label={"View measurement #{m.id} details"}
                      phx-click="select_measurement"
                      phx-value-id={m.id}
                      class="rounded-md border border-base-300 px-2 py-1 text-xs font-semibold hover:bg-base-200"
                    >
                      Details
                    </button>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
          <div class="flex items-center justify-between text-sm text-base-content/60">
            <span id="admin-measurements-count">Showing {@loaded_count} of {@total}</span>
            <button
              :if={@loaded_count < @total}
              id="load-more"
              type="button"
              phx-click="load_more"
              class="rounded-md border border-base-300 px-3 py-1.5 font-semibold text-base-content transition-colors hover:bg-base-200"
            >
              Load more
            </button>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
