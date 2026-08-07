defmodule LivedataWeb.DashboardLiveTest do
  use LivedataWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Livedata.ProjectParcels.ProjectParcel
  alias Livedata.Projects.Project
  alias Livedata.Repo

  @boundary %Geo.MultiPolygon{
    coordinates: [[[{0.0, 0.0}, {1.0, 0.0}, {1.0, 1.0}, {0.0, 1.0}, {0.0, 0.0}]]],
    srid: 4326
  }

  # The map is drawn from parcel geometry, so a project only shows up once it
  # has a parcel — which registration always creates. (@req: CRCF-37)
  defp insert_project_with_parcel(name) do
    commissioned_at = DateTime.utc_now()

    project =
      %Project{}
      |> Project.changeset(%{
        name: name,
        description: "Description of #{name}",
        commissioned_at: commissioned_at
      })
      |> Repo.insert!()

    %ProjectParcel{}
    |> ProjectParcel.create_changeset(project.id, %{
      parcel_ref: "LPIS-IT-001",
      data_source: "LPIS",
      boundary: @boundary,
      commissioned_at: commissioned_at
    })
    |> Repo.insert!()

    project
  end

  test "shows the empty state and a register link when there are no projects", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#app-header", "Air2Tree")
    assert has_element?(view, "#dashboard-empty")
    assert has_element?(view, "#register-project-link")
    assert has_element?(view, "#projects-map")
    refute has_element?(view, "#projects-list")
  end

  test "lists each registered project's name and description above the map", %{conn: conn} do
    project = insert_project_with_parcel("Listed Project")

    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#projects-list #project-#{project.id}", "Listed Project")
    assert has_element?(view, "#projects-list #project-#{project.id}", "Description of")
  end

  test "embeds a parcel's boundary into the map container", %{conn: conn} do
    insert_project_with_parcel("Visible Project")
    {:ok, view, _html} = live(conn, ~p"/")
    refute has_element?(view, "#dashboard-empty")
    map_html = view |> element("#projects-map") |> render()
    assert map_html =~ "FeatureCollection"
    assert map_html =~ "Visible Project"
  end
end
