defmodule LivedataWeb.DashboardLive do
  # @req: KR 2.1
  use LivedataWeb, :live_view

  alias Livedata.Projects
  alias Livedata.Geo.GeoJSON

  @impl true
  def mount(_params, _session, socket) do
    projects = Projects.list_projects()

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:projects, projects)
     |> assign(:projects_geojson, feature_collection(projects))}
  end

  defp feature_collection(projects) do
    features =
      for project <- projects do
        %{
          "type" => "Feature",
          "geometry" => GeoJSON.encode_geometry(project.spatial_boundary),
          "properties" => %{"id" => project.id, "name" => project.name}
        }
      end

    Jason.encode!(%{"type" => "FeatureCollection", "features" => features})
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-2xl font-semibold">Your projects</h1>
        <.link
          id="register-project-link"
          navigate={~p"/projects/new"}
          class="rounded-md bg-zinc-900 px-4 py-2 text-sm font-semibold text-white hover:bg-zinc-700"
        >
          Register project
        </.link>
      </div>

      <div
        :if={@projects == []}
        id="dashboard-empty"
        class="mb-4 rounded-md border border-dashed border-zinc-300 p-6 text-center text-zinc-500"
      >
        No projects yet. Register your first project to see it on the map.
      </div>

      <div
        id="projects-map"
        phx-hook="ProjectsMap"
        phx-update="ignore"
        data-projects={@projects_geojson}
        class="h-96 w-full rounded-lg border border-zinc-200"
      >
      </div>
    </Layouts.app>
    """
  end
end
