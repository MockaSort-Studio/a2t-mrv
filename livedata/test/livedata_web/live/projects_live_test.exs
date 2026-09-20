defmodule LivedataWeb.ProjectsLiveTest do
  # Inserts raw measurements — must not run async.
  use LivedataWeb.ConnCase, async: false
  import Phoenix.LiveViewTest
  import Livedata.Fixtures

  # / is intentionally unguarded (any authenticated user) until #61 separates
  # admin and user dashboards — log_in_user is correct here, not log_in_admin.
  setup %{conn: conn} do
    {:ok, conn: log_in_user(conn)}
  end

  describe "empty state" do
    test "shows the empty row when there are no projects", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#admin-map")
      assert has_element?(view, "#admin-projects-empty")
    end
  end

  describe "project table" do
    test "renders a row per project with key metadata", %{conn: conn} do
      %{project: project} = portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#admin-projects #projects-#{project.id}", project.name)
      assert has_element?(view, "#projects-#{project.id}", "Draft")
      refute has_element?(view, "#admin-projects-empty")
    end

    test "project name links to the project show page", %{conn: conn} do
      %{project: project} = portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/")

      assert view
             |> element("#projects-#{project.id} a[href='/projects/#{project.id}']")
             |> has_element?()
    end

    test "measurement count is shown for a project with measurements", %{conn: conn} do
      %{project: project, activity: activity} = portfolio_fixture()
      measurement_fixture(activity.id, DateTime.utc_now())

      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#projects-#{project.id}", "1")
    end

    test "embeds parcel GeoJSON in the map container", %{conn: conn} do
      portfolio_fixture(project: %{name: "Mapped Project"})

      {:ok, view, _html} = live(conn, ~p"/")

      map_html = view |> element("#admin-map") |> render()
      assert map_html =~ "FeatureCollection"
      assert map_html =~ "Mapped Project"
    end
  end

  describe "sort" do
    test "clicking the name header toggles sort direction", %{conn: conn} do
      portfolio_fixture(project: %{name: "Alpha"})
      portfolio_fixture(project: %{name: "Zeta"})

      {:ok, view, _html} = live(conn, ~p"/")

      # First click → asc
      render_click(element(view, "#sort-name"))
      html_asc = render(view)

      # Second click → desc
      render_click(element(view, "#sort-name"))
      html_desc = render(view)

      # Order should be reversed between the two renders
      assert String.length(html_asc) > 0
      assert html_asc != html_desc
    end

    test "clicking measurement count header sorts the table", %{conn: conn} do
      portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#sort-measurements"))
      assert has_element?(view, "#admin-projects")
    end

    test "clicking last-measured header sorts the table", %{conn: conn} do
      portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/")

      render_click(element(view, "#sort-last-measured"))
      assert has_element?(view, "#admin-projects")
    end
  end

  describe "map interaction" do
    test "clicking a row marks the project as selected", %{conn: conn} do
      %{project: project} = portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/")
      render_click(element(view, "#projects-#{project.id}"))

      assert view
             |> element("#projects-#{project.id}")
             |> render() =~ "bg-base-200/50"
    end

    test "map_selected_project event marks the row as selected", %{conn: conn} do
      %{project: project} = portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/")
      render_hook(view, "map_selected_project", %{"project_id" => project.id})

      assert view
             |> element("#projects-#{project.id}")
             |> render() =~ "bg-base-200/50"
    end
  end

  describe "live updates" do
    test "a PubSub :activity_created broadcast refreshes the table", %{conn: conn} do
      %{project: project} = portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "#projects-#{project.id}")

      # Simulate a second activity being added to the same project
      new_activity = activity_fixture(project.id)

      Phoenix.PubSub.broadcast(
        Livedata.PubSub,
        "activities:new",
        {:activity_created, new_activity}
      )

      # render/1 flushes pending handle_info messages
      render(view)

      assert has_element?(view, "#projects-#{project.id}")
    end
  end
end
