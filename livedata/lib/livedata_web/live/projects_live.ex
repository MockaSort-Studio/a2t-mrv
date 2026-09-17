defmodule LivedataWeb.ProjectsLive do
  @moduledoc """
  Project dashboard — sortable table of all projects with activity types,
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
  alias Livedata.Projects.ActivityForm
  alias Livedata.Registration
  alias Livedata.Registration.ProjectForm
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
     |> assign(:projects_empty?, projects == [])
     |> assign(:parcels_geojson, ProjectParcels.feature_collection(parcels))
     |> assign(:show_registration, false)
     |> reset_registration_modal()
     |> stream(:projects, sorted(projects, sort))}
  end

  @impl true
  @sortable_columns ~w(name measurement_count last_measured_at)

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

  def handle_event("open_registration", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_registration, true)
     |> reset_registration_modal()
     |> assign(:methodology_options, Enum.map(Projects.list_methodologies(), &{&1.name, &1.id}))}
  end

  def handle_event("close_registration", _params, socket) do
    {:noreply, assign(socket, :show_registration, false)}
  end

  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    {:noreply, assign(socket, :active_tab, String.to_existing_atom(tab))}
  end

  def handle_event("validate_project", %{"project" => params}, socket) do
    changeset = %ProjectForm{} |> ProjectForm.changeset(params) |> Map.put(:action, :validate)
    {:noreply, assign_project_form(socket, changeset)}
  end

  def handle_event("create_project", %{"project" => params}, socket) do
    case Registration.register_project(params) do
      {:ok, project} ->
        Enum.each(socket.assigns.pending_activities, fn %{params: ap} ->
          Projects.create_activity(project.id, ap)
        end)

        {:noreply,
         socket
         |> assign(:show_registration, false)
         |> reload_projects()
         |> put_flash(:info, "Project registered: #{project.name}")}

      {:error, changeset} ->
        {:noreply,
         socket
         |> assign(:active_tab, :project)
         |> assign_project_form(changeset)}
    end
  end

  def handle_event("toggle_activity_form", _params, socket) do
    open? = !socket.assigns.activity_form_open

    {:noreply,
     socket
     |> assign(:activity_form_open, open?)
     |> assign(:activity_form_expanded, false)
     |> assign(:activity_form_valid, false)
     |> then(fn s ->
       if open?,
         do: assign_activity_form(s, ActivityForm.changeset(%ActivityForm{}, %{})),
         else: s
     end)}
  end

  def handle_event("toggle_activity_expanded", _params, socket) do
    {:noreply, assign(socket, :activity_form_expanded, !socket.assigns.activity_form_expanded)}
  end

  def handle_event("validate_activity", %{"activity" => params}, socket) do
    changeset = %ActivityForm{} |> ActivityForm.changeset(params) |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(:activity_form_valid, changeset.valid?)
     |> assign_activity_form(changeset)}
  end

  def handle_event("add_pending_activity", %{"activity" => params}, socket) do
    changeset = ActivityForm.changeset(%ActivityForm{}, params)

    if changeset.valid? do
      form = Ecto.Changeset.apply_changes(changeset)
      id = socket.assigns.next_activity_id

      pending = %{
        id: id,
        name: form.activity_name,
        type: form.activity_type,
        params: params
      }

      {:noreply,
       socket
       |> assign(:pending_activities, socket.assigns.pending_activities ++ [pending])
       |> assign(:next_activity_id, id + 1)
       |> assign(:activity_form_open, false)
       |> assign(:activity_form_expanded, false)
       |> assign(:activity_form_valid, false)
       |> assign_activity_form(ActivityForm.changeset(%ActivityForm{}, %{}))}
    else
      {:noreply, assign_activity_form(socket, Map.put(changeset, :action, :validate))}
    end
  end

  def handle_event("remove_pending_activity", %{"id" => id_str}, socket) do
    id = String.to_integer(id_str)
    pending = Enum.reject(socket.assigns.pending_activities, &(&1.id == id))
    {:noreply, assign(socket, :pending_activities, pending)}
  end

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
    {:noreply, reload_projects(socket)}
  end

  defp reload_projects(socket) do
    projects = Projects.list_projects_for_admin()
    parcels = ProjectParcels.list_parcels_with_project()

    socket
    |> assign(:projects_raw, projects)
    |> assign(:projects_empty?, projects == [])
    |> assign(:parcels_geojson, ProjectParcels.feature_collection(parcels))
    |> stream(:projects, sorted(projects, socket.assigns.sort), reset: true)
  end

  defp reset_registration_modal(socket) do
    socket
    |> assign(:active_tab, :project)
    |> assign(:pending_activities, [])
    |> assign(:next_activity_id, 0)
    |> assign(:activity_form_open, false)
    |> assign(:activity_form_expanded, false)
    |> assign(:activity_form_valid, false)
    |> assign(:methodology_options, [])
    |> assign_project_form(ProjectForm.changeset(%ProjectForm{}, %{}))
    |> assign_activity_form(ActivityForm.changeset(%ActivityForm{}, %{}))
  end

  defp assign_project_form(socket, changeset) do
    assign(socket, :project_form, to_form(changeset, as: :project))
  end

  defp assign_activity_form(socket, changeset) do
    assign(socket, :activity_form, to_form(changeset, as: :activity))
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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} max_width="max-w-7xl">
      <%!-- Registration modal --%>
      <div
        :if={@show_registration}
        id="registration-backdrop"
        class="fixed inset-0 z-40 bg-black/40"
        phx-click="close_registration"
      >
      </div>
      <div
        :if={@show_registration}
        id="registration-centering"
        class="pointer-events-none fixed inset-0 z-50 flex items-center justify-center px-4"
      >
        <div
          id="registration-modal"
          class="pointer-events-auto relative flex w-full max-w-lg flex-col rounded-xl bg-base-100 shadow-2xl ring-1 ring-base-300"
          style="height: min(90vh, 780px);"
        >
          <%!-- Header --%>
          <div class="flex shrink-0 items-center justify-between border-b border-base-300 px-6 py-4">
            <h2 class="text-lg font-semibold">Register a project</h2>
            <button
              id="close-registration"
              type="button"
              phx-click="close_registration"
              class="rounded-md p-1 text-base-content/50 transition-colors hover:bg-base-200 hover:text-base-content"
            >
              <.icon name="hero-x-mark" class="size-5" />
            </button>
          </div>

          <%!-- Tabs --%>
          <div class="flex shrink-0 border-b border-base-300">
            <button
              id="tab-project"
              type="button"
              phx-click="switch_tab"
              phx-value-tab="project"
              class={[
                "flex-1 px-4 py-2.5 text-sm font-medium transition-colors",
                if(@active_tab == :project,
                  do: "border-b-2 border-primary text-primary",
                  else: "text-base-content/60 hover:text-base-content"
                )
              ]}
            >
              Project info
            </button>
            <button
              id="tab-activities"
              type="button"
              phx-click="switch_tab"
              phx-value-tab="activities"
              class={[
                "flex-1 px-4 py-2.5 text-sm font-medium transition-colors",
                if(@active_tab == :activities,
                  do: "border-b-2 border-primary text-primary",
                  else: "text-base-content/60 hover:text-base-content"
                )
              ]}
            >
              Activities
              <span
                :if={@pending_activities != []}
                class="ml-1.5 rounded-full bg-primary px-1.5 py-0.5 text-xs text-primary-content"
              >
                {length(@pending_activities)}
              </span>
            </button>
          </div>

          <%!-- Tab content area (flex-1, both panels always in DOM) --%>
          <div class="relative flex-1 overflow-hidden">
            <%!-- Tab: Project info --%>
            <div class={[
              "absolute inset-0 overflow-y-auto px-6 py-5",
              @active_tab != :project && "hidden"
            ]}>
              <.form
                for={@project_form}
                id="project-form"
                phx-change="validate_project"
                phx-submit="create_project"
                class="space-y-6"
              >
                <section class="space-y-3">
                  <h3 class="border-b border-base-300 pb-1 text-sm font-semibold uppercase tracking-wide text-base-content/50">
                    Project
                  </h3>
                  <.input field={@project_form[:project_name]} type="text" label="Project name" />
                  <.input
                    field={@project_form[:project_description]}
                    type="textarea"
                    label="Description"
                  />
                </section>

                <section class="space-y-3">
                  <h3 class="border-b border-base-300 pb-1 text-sm font-semibold uppercase tracking-wide text-base-content/50">
                    Parcel
                  </h3>
                  <.input field={@project_form[:parcel_ref]} type="text" label="Parcel reference" />
                  <.input
                    field={@project_form[:parcel_data_source]}
                    type="select"
                    label="Data source"
                    prompt="Choose a source"
                    options={["LPIS", "CADASTER"]}
                  />
                  <.input
                    field={@project_form[:parcel_boundary_geojson]}
                    type="textarea"
                    label="Parcel boundary (GeoJSON MultiPolygon)"
                  />
                </section>
              </.form>
            </div>

            <%!-- Tab: Activities --%>
            <div class={[
              "absolute inset-0 flex flex-col px-6 py-5",
              @active_tab != :activities && "hidden"
            ]}>
              <div class="flex min-h-0 flex-1 flex-col rounded-lg border border-dashed border-base-300">
                <div class="flex-1 overflow-y-auto p-3 space-y-2">
                  <.activity_inline_form
                    :if={@activity_form_open}
                    form={@activity_form}
                    expanded={@activity_form_expanded}
                    valid={@activity_form_valid}
                    methodology_options={@methodology_options}
                  />

                  <%!-- Committed activity cards --%>
                  <div
                    :for={a <- @pending_activities}
                    id={"pending-activity-#{a.id}"}
                    class="flex items-center justify-between rounded-lg px-4 py-3 ring-1 ring-base-300"
                  >
                    <div>
                      <span class="font-medium">{a.name}</span>
                      <span class="ml-2 rounded-full bg-base-200 px-2 py-0.5 text-xs text-base-content/60">
                        {Format.activity_type(a.type)}
                      </span>
                    </div>
                    <button
                      type="button"
                      phx-click="remove_pending_activity"
                      phx-value-id={a.id}
                      class="rounded p-1 text-base-content/40 transition-colors hover:bg-base-200 hover:text-base-content"
                    >
                      <.icon name="hero-x-mark-micro" class="size-3.5" />
                    </button>
                  </div>
                </div>

                <%!-- Add activity — pinned at bottom, outside scroll area --%>
                <button
                  id="open-activity-form"
                  type="button"
                  phx-click="toggle_activity_form"
                  disabled={@activity_form_open}
                  class={[
                    "flex w-full shrink-0 items-center justify-center gap-1.5 rounded-b-lg border-t border-dashed border-base-300 px-4 py-2.5 text-sm font-medium transition-colors",
                    if(@activity_form_open,
                      do: "cursor-default text-base-content/20",
                      else: "text-base-content/60 hover:bg-base-200 hover:text-base-content"
                    )
                  ]}
                >
                  <.icon name="hero-plus-micro" class="size-4" /> Add activity
                </button>
              </div>
            </div>
          </div>

          <%!-- Shared footer — always at bottom regardless of active tab --%>
          <div class="shrink-0 flex gap-3 border-t border-base-300 px-6 py-4">
            <button
              type="submit"
              form="project-form"
              phx-disable-with="Creating…"
              class="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-content transition-colors hover:opacity-90"
            >
              Create project
            </button>
            <button
              type="button"
              phx-click="close_registration"
              class="rounded-md px-4 py-2 text-sm font-semibold text-base-content/50 transition-colors hover:text-base-content"
            >
              Cancel
            </button>
          </div>
        </div>
      </div>

      <%!-- Viewport-filling layout: navbar (4rem) + py-10 (5rem) = 9rem overhead --%>
      <div class="flex h-[calc(100vh-9rem)] flex-col gap-4">
        <div class="flex shrink-0 items-center gap-3">
          <h1 class="text-2xl font-semibold">Projects</h1>
          <button
            id="register-project-btn"
            type="button"
            phx-click="open_registration"
            class="flex items-center justify-center size-7 rounded-md border border-base-300 text-base-content/60 transition-colors hover:bg-base-200 hover:text-base-content"
            title="Register project"
          >
            <.icon name="hero-plus-micro" class="size-4" />
          </button>
        </div>

        <div class="grid min-h-0 flex-1 gap-4 lg:grid-cols-5">
          <%!-- Table — 3 of 5 columns, scrolls internally --%>
          <div class="flex min-h-0 flex-col lg:col-span-3">
            <div
              :if={@projects_empty?}
              id="admin-projects-empty"
              class="rounded-lg border border-dashed border-base-300 p-8 text-center text-sm text-base-content/60"
            >
              No projects registered yet.
            </div>

            <div :if={!@projects_empty?} class="overflow-auto rounded-lg border border-base-300">
              <table class="w-full text-sm">
                <thead class="sticky top-0 z-10">
                  <tr class="border-b border-base-300 bg-base-200 text-left text-xs font-medium uppercase tracking-wide text-base-content/60">
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
                    <th class="px-4 py-3 normal-case">Status</th>
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
                <tbody id="admin-projects" phx-update="stream" class="divide-y divide-base-300">
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
                      <.link navigate={~p"/projects/#{p.id}"} class="hover:underline">
                        {p.name}
                      </.link>
                    </td>
                    <td class="px-4 py-3">
                      <span class="rounded-full bg-base-200 px-2 py-0.5 text-xs font-medium text-base-content/70">
                        {String.capitalize(p.status)}
                      </span>
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

          <%!-- Map — 2 of 5 columns, fills grid row height --%>
          <div class="lg:col-span-2">
            <div
              id="admin-map"
              phx-hook="ProjectsMap"
              phx-update="ignore"
              data-projects={@parcels_geojson}
              class="h-64 w-full rounded-lg border border-base-300 lg:h-full"
            >
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
