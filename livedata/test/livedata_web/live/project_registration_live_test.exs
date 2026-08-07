defmodule LivedataWeb.ProjectRegistrationLiveTest do
  use LivedataWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Livedata.Repo
  alias Livedata.Projects.Project

  @multipolygon ~s({"type":"MultiPolygon","coordinates":[[[[0.0,0.0],[1.0,0.0],[1.0,1.0],[0.0,1.0],[0.0,0.0]]]]})

  @valid %{
    "project_name" => "Test Project",
    "project_description" => "A test project",
    "parcel_ref" => "LPIS-IT-001",
    "parcel_data_source" => "LPIS",
    "parcel_boundary_geojson" => @multipolygon
  }

  test "renders the registration form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/projects/new")
    assert has_element?(view, "#project-registration-form")
  end

  test "shows validation errors on invalid change", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/projects/new")

    html =
      view
      |> form("#project-registration-form")
      |> render_change(%{"registration" => %{"parcel_data_source" => "NOPE"}})

    assert html =~ "is invalid"
  end

  # A raise in the validate path kills the LiveView, and the remount hands the
  # operator an empty form — so "the other fields are cleared" is the symptom of
  # a crash, not of validation. Assert the typed values survive the error.
  test "a boundary that is valid JSON but not GeoJSON keeps the other fields", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/projects/new")

    for bad <- ["[[[[0.0,0.0],[1.0,0.0],[1.0,1.0],[0.0,0.0]]]]", "123", "null"] do
      html =
        view
        |> form("#project-registration-form")
        |> render_change(%{"registration" => Map.put(@valid, "parcel_boundary_geojson", bad)})

      assert html =~ "is not valid GeoJSON"
      assert html =~ "Test Project"
      assert html =~ "LPIS-IT-001"
    end
  end

  test "valid submission creates a project and redirects to the dashboard", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/projects/new")

    assert {:error, {:live_redirect, %{to: "/"}}} =
             view
             |> form("#project-registration-form", registration: @valid)
             |> render_submit()

    assert Repo.aggregate(Project, :count) == 1
  end
end
