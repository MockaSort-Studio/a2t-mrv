defmodule LivedataWeb.DashboardLive do
  # @req: KR 2.1
  use LivedataWeb, :live_view

  alias Livedata.ProjectParcels
  alias Livedata.Projects
  alias Livedata.Geo.GeoJSON

  @impl true
  def mount(_params, _session, socket) do
    projects = Projects.list_projects()
    parcels = ProjectParcels.list_parcels_with_project()

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:projects, projects)
     |> assign(:parcels_geojson, feature_collection(parcels))}
  end

  # Boundaries are recorded on parcels, so the map is drawn from parcel
  # geometry, labelled with the project each parcel belongs to. (@req: CRCF-37)
  defp feature_collection(parcels) do
    features =
      for parcel <- parcels do
        %{
          "type" => "Feature",
          "geometry" => GeoJSON.encode_geometry(parcel.boundary),
          "properties" => %{
            "project_id" => parcel.project_id,
            "name" => parcel.project_name,
            "parcel_ref" => parcel.parcel_ref
          }
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
        data-projects={@parcels_geojson}
        class="h-96 w-full rounded-lg border border-zinc-200"
      >
      </div>
    </Layouts.app>
    """
  end
end
