defmodule LivedataWeb.AdminLive do
  @moduledoc """
  Admin project dashboard — sortable table of all projects with activity types,
  measurement counts, and a linked Leaflet map.

  Selecting a table row highlights the project's parcels on the map and vice
  versa, reusing the existing `ProjectsMap` JS hook.

  Subscribes to `"activities:new"` so the table refreshes live when a new
  activity (and therefore a potentially new project) is registered.
  (@req: CRCF-34)
  """
  use LivedataWeb, :live_view

  alias Livedata.ProjectParcels
  alias Livedata.Projects
  alias LivedataWeb.Format

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Projects.subscribe_activities()

    projects = Projects.list_projects_for_admin()
    parcels = ProjectParcels.list_parcels_with_project()
    sort = {:last_measured_at, :desc}

    {:ok,
     socket
     |> assign(:page_title, "Air2Tree-MRV")
     |> assign(:projects_raw, projects)
     |> assign(:sort, sort)
     |> assign(:selected_project_id, nil)
     |> assign(:stats, stats(projects))
     |> assign(:projects_empty?, projects == [])
     |> assign(:parcels_geojson, ProjectParcels.feature_collection(parcels))
     |> stream(:projects, sorted(projects, sort))}
  end

  @impl true
  @sortable_columns ~w(name measurement_count last_measured_at activity_count)

  def handle_event("sort", %{"col" => col_str}, socket) when col_str in @sortable_columns do
    col = String.to_existing_atom(col_str)
    current = socket.assigns.sort

    new_sort =
      case current do
        {^col, :asc} -> {col, :desc}
        {^col, :desc} -> {col, :asc}
        _ -> {col, :asc}
      end

    {:noreply,
     socket
     |> assign(:sort, new_sort)
     |> stream(:projects, sorted(socket.assigns.projects_raw, new_sort), reset: true)}
  end

  def handle_event("sort", _params, socket), do: {:noreply, socket}

  def handle_event("select_project", %{"project-id" => project_id}, socket) do
    {:noreply,
     socket
     |> assign(:selected_project_id, project_id)
     |> push_event("highlight_project", %{project_id: project_id})}
  end

  def handle_event("map_selected_project", %{"project_id" => project_id}, socket) do
    {:noreply, assign(socket, :selected_project_id, project_id)}
  end

  @impl true
  def handle_info({:activity_created, _activity}, socket) do
    projects = Projects.list_projects_for_admin()
    parcels = ProjectParcels.list_parcels_with_project()

    {:noreply,
     socket
     |> assign(:projects_raw, projects)
     |> assign(:stats, stats(projects))
     |> assign(:projects_empty?, projects == [])
     |> assign(:parcels_geojson, ProjectParcels.feature_collection(parcels))
     |> stream(:projects, sorted(projects, socket.assigns.sort), reset: true)}
  end

  defp stats(projects) do
    %{
      projects: length(projects),
      activities: Enum.sum(Enum.map(projects, & &1.activity_count)),
      measurements: Enum.sum(Enum.map(projects, & &1.measurement_count))
    }
  end

  defp sorted(projects, {col, dir}) do
    Enum.sort_by(projects, &sort_key(&1, col), dir)
  end

  defp sort_key(%{last_measured_at: nil}, :last_measured_at), do: 0
  defp sort_key(%{last_measured_at: dt}, :last_measured_at), do: DateTime.to_unix(dt)
  defp sort_key(row, :name), do: String.downcase(row.name)
  defp sort_key(row, col), do: Map.get(row, col) || 0

  defp sort_indicator({col, :asc}, col), do: "↑"
  defp sort_indicator({col, :desc}, col), do: "↓"
  defp sort_indicator(_, _), do: "↕"

  defp type_pill_class("PERMANENT_REMOVAL"), do: "bg-emerald-100 text-emerald-800"
  defp type_pill_class("FARMING_SEQUESTRATION"), do: "bg-amber-100 text-amber-800"
  defp type_pill_class("PRODUCT_STORAGE"), do: "bg-sky-100 text-sky-800"
  defp type_pill_class("SOIL_EMISSION_REDUCTION"), do: "bg-orange-100 text-orange-800"
  defp type_pill_class(_), do: "bg-zinc-100 text-zinc-700"

  defp type_short("PERMANENT_REMOVAL"), do: "Removal"
  defp type_short("FARMING_SEQUESTRATION"), do: "Farming"
  defp type_short("PRODUCT_STORAGE"), do: "Storage"
  defp type_short("SOIL_EMISSION_REDUCTION"), do: "Soil"
  defp type_short(other), do: other

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} max_width="max-w-7xl">
      <div class="flex flex-wrap items-center justify-between gap-3">
        <h1 class="text-2xl font-semibold">Projects</h1>

        <div id="admin-stats" class="flex flex-wrap gap-4 text-sm text-base-content/60">
          <span id="stat-admin-projects">
            <span class="font-semibold text-base-content">{@stats.projects}</span> projects
          </span>
          <span id="stat-admin-activities">
            <span class="font-semibold text-base-content">{@stats.activities}</span> activities
          </span>
          <span id="stat-admin-measurements">
            <span class="font-semibold text-base-content">{@stats.measurements}</span> measurements
          </span>
        </div>
      </div>

      <div class="grid gap-4 lg:grid-cols-5">
        <%!-- Table — 3 of 5 columns --%>
        <div class="lg:col-span-3">
          <div
            :if={@projects_empty?}
            id="admin-projects-empty"
            class="rounded-lg border border-dashed border-zinc-300 p-8 text-center text-sm text-base-content/60"
          >
            No projects registered yet.
          </div>

          <div :if={!@projects_empty?} class="overflow-x-auto rounded-lg border border-zinc-200">
            <table class="w-full text-sm">
              <thead>
                <tr class="border-b border-zinc-200 bg-zinc-50 text-left text-xs font-medium uppercase tracking-wide text-base-content/60">
                  <th class="px-4 py-3">
                    <button
                      id="sort-name"
                      phx-click="sort"
                      phx-value-col="name"
                      class="flex items-center gap-1 hover:text-base-content"
                    >
                      Name <span class="opacity-50">{sort_indicator(@sort, :name)}</span>
                    </button>
                  </th>
                  <th class="px-4 py-3">Status</th>
                  <th class="px-4 py-3">Types</th>
                  <th class="px-4 py-3">
                    <button
                      id="sort-measurements"
                      phx-click="sort"
                      phx-value-col="measurement_count"
                      class="flex items-center gap-1 hover:text-base-content"
                    >
                      Measurements
                      <span class="opacity-50">{sort_indicator(@sort, :measurement_count)}</span>
                    </button>
                  </th>
                  <th class="px-4 py-3">
                    <button
                      id="sort-last-measured"
                      phx-click="sort"
                      phx-value-col="last_measured_at"
                      class="flex items-center gap-1 hover:text-base-content"
                    >
                      Last measured
                      <span class="opacity-50">{sort_indicator(@sort, :last_measured_at)}</span>
                    </button>
                  </th>
                </tr>
              </thead>
              <tbody id="admin-projects" phx-update="stream" class="divide-y divide-zinc-100">
                <tr
                  :for={{dom_id, p} <- @streams.projects}
                  id={dom_id}
                  phx-click="select_project"
                  phx-value-project-id={p.id}
                  class={[
                    "cursor-pointer transition-colors hover:bg-base-200/50",
                    @selected_project_id == p.id && "bg-base-200/50"
                  ]}
                >
                  <td class="px-4 py-3 font-medium">
                    <.link
                      navigate={~p"/projects/#{p.id}"}
                      class="hover:underline"
                    >
                      {p.name}
                    </.link>
                  </td>
                  <td class="px-4 py-3">
                    <span class="rounded-full bg-zinc-100 px-2 py-0.5 text-xs font-medium text-zinc-600">
                      {p.status}
                    </span>
                  </td>
                  <td class="px-4 py-3">
                    <div class="flex flex-wrap gap-1">
                      <span
                        :for={type <- p.activity_types}
                        class={[
                          "rounded-full px-2 py-0.5 text-xs font-medium",
                          type_pill_class(type)
                        ]}
                      >
                        {type_short(type)}
                      </span>
                      <span :if={p.activity_types == []} class="text-base-content/40">—</span>
                    </div>
                  </td>
                  <td class="px-4 py-3 tabular-nums text-base-content/70">
                    {p.measurement_count}
                  </td>
                  <%!-- @req: CRCF-20 — relative time is zone-independent --%>
                  <td
                    class="px-4 py-3 text-base-content/60"
                    title={Format.utc(p.last_measured_at)}
                  >
                    {Format.relative_time(p.last_measured_at)}
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <%!-- Map — 2 of 5 columns, sticky on desktop --%>
        <div class="lg:col-span-2">
          <div
            id="admin-map"
            phx-hook="ProjectsMap"
            phx-update="ignore"
            data-projects={@parcels_geojson}
            class="h-80 w-full rounded-lg border border-zinc-200 lg:sticky lg:top-4 lg:h-[calc(100vh-8rem)]"
          >
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
