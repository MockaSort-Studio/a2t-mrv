defmodule LivedataWeb.DashboardLiveTest do
  # Inserts raw measurements (hypertable) — must not run async.
  use LivedataWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Livedata.Fixtures

  alias Livedata.Monitoring

  describe "empty portfolio" do
    test "shows the empty states and the primary actions", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#app-header", "Air2Tree")
      assert has_element?(view, "#app-nav #nav-record")
      assert has_element?(view, "#dashboard-stats #stat-projects")
      assert has_element?(view, "#dashboard-empty")
      assert has_element?(view, "#attention-empty")
      assert has_element?(view, "#record-measurement-link")
      assert has_element?(view, "#register-project-link")
      assert has_element?(view, "#projects-map")
      refute has_element?(view, "#projects-list")
      refute has_element?(view, "#attention-list")
    end
  end

  describe "portfolio roll-up" do
    test "renders a card per project with its counts", %{conn: conn} do
      %{project: project} = portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#projects-list #project-card-#{project.id}", project.name)
      assert has_element?(view, "#project-card-#{project.id}", "1 activities")
      assert has_element?(view, "#project-card-#{project.id}", "1 parcels")
      refute has_element?(view, "#dashboard-empty")
    end

    test "embeds parcel boundaries into the map container", %{conn: conn} do
      portfolio_fixture(project: %{name: "Visible Project"})

      {:ok, view, _html} = live(conn, ~p"/")

      map_html = view |> element("#projects-map") |> render()
      assert map_html =~ "FeatureCollection"
      assert map_html =~ "Visible Project"
    end

    test "selecting a project card marks it as selected", %{conn: conn} do
      %{project: project} = portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/")
      render_click(element(view, "#project-card-#{project.id}"))

      assert view
             |> element("#project-card-#{project.id}")
             |> render() =~ "border-zinc-900"
    end
  end

  describe "needs attention" do
    test "lists a never-measured activity with a pre-scoped record link", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#attention-list #attention-#{activity.id}", "never measured")
      assert has_element?(view, "#attention-record-#{activity.id}")
      refute has_element?(view, "#attention-empty")
    end

    test "the record link carries the activity so the form is pre-scoped", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/")

      {:ok, entry_view, _html} =
        view
        |> element("#attention-record-#{activity.id}")
        |> render_click()
        |> follow_redirect(conn)

      assert has_element?(entry_view, "#measurement-entry-form")

      assert entry_view
             |> element("#measurement-entry-form")
             |> render() =~ activity.id
    end

    test "a freshly measured activity drops off the list", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()
      measurement_fixture(activity.id, DateTime.utc_now())

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#attention-empty")
      refute has_element?(view, "#attention-#{activity.id}")
    end

    test "a stale activity is listed with its age", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()
      days = Monitoring.stale_after_days() + 3
      measurement_fixture(activity.id, DateTime.add(DateTime.utc_now(), -days, :day))

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#attention-#{activity.id}", "no data for")
    end
  end

  describe "recent submissions" do
    test "streams the latest measurements with their project and activity", %{conn: conn} do
      %{project: project, activity: activity} = portfolio_fixture()
      measurement = measurement_fixture(activity.id, DateTime.utc_now(), %{"soc" => 2.5})

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#recent-measurements #recent-#{measurement.id}", project.name)
      assert has_element?(view, "#recent-#{measurement.id}", "MANUAL_ENTRY")
      assert has_element?(view, "#recent-#{measurement.id}", "soc: 2.5")
    end
  end
end
