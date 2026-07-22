defmodule LivedataWeb.DashboardLiveTest do
  use LivedataWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Livedata.Projects.Project
  alias Livedata.Repo

  @boundary %Geo.MultiPolygon{
    coordinates: [[[{0.0, 0.0}, {1.0, 0.0}, {1.0, 1.0}, {0.0, 1.0}, {0.0, 0.0}]]],
    srid: 4326
  }

  defp insert_project(name) do
    %Project{}
    |> Project.changeset(%{
      name: name,
      spatial_boundary: @boundary,
      commissioned_at: DateTime.utc_now()
    })
    |> Repo.insert!()
  end

  test "shows the empty state and a register link when there are no projects", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#dashboard-empty")
    assert has_element?(view, "#register-project-link")
    assert has_element?(view, "#projects-map")
  end

  test "embeds a project's boundary into the map container", %{conn: conn} do
    insert_project("Visible Project")
    {:ok, view, _html} = live(conn, ~p"/")
    refute has_element?(view, "#dashboard-empty")
    map_html = view |> element("#projects-map") |> render()
    assert map_html =~ "FeatureCollection"
    assert map_html =~ "Visible Project"
  end
end
