defmodule LivedataWeb.ProjectShowLiveTest do
  # Inserts raw measurements (hypertable) — must not run async.
  use LivedataWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Livedata.Fixtures

  test "renders the project header, its UUID and the add-activity action", %{conn: conn} do
    %{project: project} = portfolio_fixture(project: %{description: "A wooded slope"})

    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}")

    assert has_element?(view, "#project-detail", project.name)
    assert has_element?(view, "#project-detail", "A wooded slope")
    # @req: CRCF-19 — the UUID is the audit handle.
    assert has_element?(view, "#project-uuid", project.id)
    assert has_element?(view, "#add-activity-link")
    assert has_element?(view, "#breadcrumbs")
  end

  test "lists the project's parcels and embeds their boundaries", %{conn: conn} do
    %{project: project, parcel: parcel} = portfolio_fixture()

    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}")

    assert has_element?(view, "#parcels-table #parcel-#{parcel.parcel_ref}", parcel.parcel_ref)
    assert has_element?(view, "#parcels-table #parcel-#{parcel.parcel_ref}", "LPIS")
    assert view |> element("#project-map") |> render() =~ "FeatureCollection"
    refute has_element?(view, "#parcels-empty")
  end

  test "lists the project's activities with their coverage", %{conn: conn} do
    %{project: project, activity: activity} = portfolio_fixture()
    measurement_fixture(activity.id, DateTime.utc_now())

    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}")

    assert has_element?(view, "#activities-table #activity-row-#{activity.id}", activity.name)
    assert has_element?(view, "#activity-row-#{activity.id}", "Permanent removal")
    assert has_element?(view, "#activity-row-#{activity.id}", "PERMANENT")
    refute has_element?(view, "#activities-empty")
  end

  test "shows empty states for a project with no parcels or activities", %{conn: conn} do
    project = project_fixture()

    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}")

    assert has_element?(view, "#parcels-empty")
    assert has_element?(view, "#activities-empty")
  end

  test "another project's activities are not listed", %{conn: conn} do
    %{project: project} = portfolio_fixture()
    %{activity: other_activity} = portfolio_fixture()

    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}")

    refute has_element?(view, "#activity-row-#{other_activity.id}")
  end

  test "raises for an unknown project", %{conn: conn} do
    assert_raise Ecto.NoResultsError, fn ->
      live(conn, ~p"/projects/#{Ecto.UUID.generate()}")
    end
  end
end
