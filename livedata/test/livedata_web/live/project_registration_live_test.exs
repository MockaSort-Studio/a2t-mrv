defmodule LivedataWeb.ProjectRegistrationLiveTest do
  use LivedataWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Livedata.Repo
  alias Livedata.Projects.Project
  alias Livedata.Projects.Activity
  alias Livedata.Projects.Methodology

  @multipolygon ~s({"type":"MultiPolygon","coordinates":[[[[0.0,0.0],[1.0,0.0],[1.0,1.0],[0.0,1.0],[0.0,0.0]]]]})

  defp valid_form_params(overrides) do
    Map.merge(
      %{
        "project_name" => "Test Project",
        "project_description" => "A test project",
        "parcel_ref" => "LPIS-IT-001",
        "parcel_data_source" => "LPIS",
        "parcel_boundary_geojson" => @multipolygon,
        "activity_name" => "Test Activity",
        "activity_description" => "A test activity",
        "activity_type" => "PERMANENT_REMOVAL",
        "activity_period_start" => "2026-01-01",
        "monitoring_period_start" => "2026-01-01",
        "methodology_ids" => []
      },
      overrides
    )
  end

  test "renders the registration form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/projects/new")
    assert has_element?(view, "#project-registration-form")
  end

  test "renders the activity section", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/projects/new")

    assert has_element?(
             view,
             "#project-registration-form select[name='registration[activity_type]']"
           )

    assert has_element?(view, "select[name='registration[methodology_ids][]']")
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
        |> render_change(%{
          "registration" => valid_form_params(%{"parcel_boundary_geojson" => bad})
        })

      assert html =~ "is not valid GeoJSON"
      assert html =~ "Test Project"
      assert html =~ "LPIS-IT-001"
    end
  end

  test "valid submission creates a project and redirects to the dashboard", %{conn: conn} do
    m = Repo.insert!(Methodology.changeset(%Methodology{}, %{name: "M1"}))
    {:ok, view, _html} = live(conn, ~p"/projects/new")

    assert {:error, {:live_redirect, %{to: "/"}}} =
             view
             |> form("#project-registration-form",
               registration: valid_form_params(%{"methodology_ids" => [m.id]})
             )
             |> render_submit()

    assert Repo.aggregate(Project, :count) == 1
  end

  test "submitting a complete form creates the activity and redirects", %{conn: conn} do
    m = Repo.insert!(Methodology.changeset(%Methodology{}, %{name: "M1"}))
    {:ok, view, _html} = live(conn, ~p"/projects/new")

    params = %{"registration" => valid_form_params(%{"methodology_ids" => [m.id]})}
    render_submit(element(view, "#project-registration-form"), params)

    assert Repo.aggregate(Activity, :count) == 1
  end
end
