defmodule LivedataWeb.ProjectShowLive do
  @moduledoc """
  A single project: the land it covers and the activities running on it.
  Measurements hang off activities, never off the project itself
  (@req: CRCF-21), so this page is a hub, not a data view — every measurement
  is one more click away, through its activity.
  """
  use LivedataWeb, :live_view

  alias Livedata.ProjectParcels
  alias Livedata.Projects
  alias Livedata.Projects.ActivityForm
  alias LivedataWeb.Format

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    project = Projects.get_project!(id)
    parcels = ProjectParcels.list_parcels_for_project(project.id)

    {:ok,
     socket
     |> assign(:page_title, project.name)
     |> assign(:project, project)
     |> assign(:parcel, List.first(parcels))
     |> assign(:activities, Projects.list_activities_with_stats(project_id: project.id))
     |> assign(:parcels_geojson, ProjectParcels.feature_collection(parcels))
     |> reset_activity_modal()}
  end

  @impl true
  def handle_event("toggle_activity_form", _params, socket) do
    open? = !socket.assigns.activity_form_open

    {:noreply,
     socket
     |> assign(:activity_form_open, open?)
     |> assign(:activity_form_expanded, false)
     |> assign(:activity_form_valid, false)
     |> then(fn s ->
       if open?,
         do:
           s
           |> assign_activity_form(ActivityForm.changeset(%ActivityForm{}, %{}))
           |> assign(
             :methodology_options,
             Enum.map(Projects.list_methodologies(), &{&1.name, &1.id})
           ),
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

  def handle_event("create_activity", %{"activity" => params}, socket) do
    case Projects.create_activity(socket.assigns.project.id, params) do
      {:ok, %{activity: activity}} ->
        {:noreply,
         socket
         |> reset_activity_modal()
         |> reload_activities()
         |> put_flash(:info, "Activity created: #{activity.name}")}

      {:error, changeset} ->
        {:noreply, assign_activity_form(socket, Map.put(changeset, :action, :validate))}
    end
  end

  defp reset_activity_modal(socket) do
    socket
    |> assign(:activity_form_open, false)
    |> assign(:activity_form_expanded, false)
    |> assign(:activity_form_valid, false)
    |> assign(:methodology_options, [])
    |> assign_activity_form(ActivityForm.changeset(%ActivityForm{}, %{}))
  end

  defp reload_activities(socket) do
    assign(
      socket,
      :activities,
      Projects.list_activities_with_stats(project_id: socket.assigns.project.id)
    )
  end

  defp assign_activity_form(socket, changeset) do
    assign(socket, :activity_form, to_form(changeset, as: :activity))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} max_width="max-w-6xl">
      <:breadcrumbs>
        <Layouts.crumb navigate={~p"/"}>Projects</Layouts.crumb>
        <Layouts.crumb>{@project.name}</Layouts.crumb>
      </:breadcrumbs>

      <div id="project-detail" class="space-y-4">
        <%!-- Header --%>
        <%!-- @req: CRCF-19 --%>
        <header>
          <div class="flex items-center gap-2">
            <h1 class="text-2xl font-semibold">{@project.name}</h1>
            <span class="rounded-full bg-base-200 px-2 py-0.5 text-xs font-medium text-base-content/70">
              {String.capitalize(@project.status)}
            </span>
          </div>
          <p class="mt-1 text-sm text-base-content/60">
            Commissioned {Format.utc(@project.commissioned_at)}
          </p>
        </header>

        <%!-- Activities (left) + Map (right) --%>
        <div class="grid gap-4 lg:grid-cols-2">
          <%!-- Activities — dashed box with floating cards, same pattern as registration modal --%>
          <div
            class="flex flex-col rounded-lg border border-dashed border-base-300"
            style="height: 32rem;"
          >
            <div class="flex-1 overflow-y-auto p-3 space-y-2">
              <div
                :if={@activities == [] and not @activity_form_open}
                id="activities-empty"
                class="px-4 py-8 text-center text-sm text-base-content/40"
              >
                No activities yet.
              </div>

              <.activity_inline_form
                :if={@activity_form_open}
                form={@activity_form}
                expanded={@activity_form_expanded}
                valid={@activity_form_valid}
                methodology_options={@methodology_options}
                submit_event="create_activity"
              />

              <.link
                :for={activity <- @activities}
                id={"activity-card-#{activity.id}"}
                navigate={~p"/activities/#{activity.id}"}
                class="block rounded-lg ring-1 ring-base-300 px-4 py-3 transition-colors hover:bg-base-200/50"
              >
                <div class="flex items-center justify-between gap-2">
                  <span class="font-medium">{activity.name}</span>
                  <span class="shrink-0 rounded-full bg-base-200 px-2 py-0.5 text-xs text-base-content/60">
                    {Format.activity_type(activity.activity_type)}
                  </span>
                </div>
                <p class="mt-1 text-xs text-base-content/50">
                  {activity.measurement_count} measurements
                  <span :if={activity.last_measured_at}>
                    · {Format.relative_time(activity.last_measured_at)}
                  </span>
                </p>
              </.link>
            </div>

            <button
              id="add-activity-bottom"
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

          <%!-- Map auto-focused on parcel boundaries --%>
          <div
            id="project-map"
            phx-hook="ProjectsMap"
            phx-update="ignore"
            data-projects={@parcels_geojson}
            data-autofocus="true"
            class="w-full rounded-lg border border-base-300"
            style="height: 32rem;"
          >
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
