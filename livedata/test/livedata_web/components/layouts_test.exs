defmodule LivedataWeb.LayoutsTest do
  use LivedataWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  describe "app/1 — primary nav" do
    # Navigate to the dashboard (which uses Layouts.app) so the nav is rendered
    # in a real LiveView context with router and endpoint wired up.
    test "renders the three primary navigation links", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "#nav-dashboard", "Dashboard")
      assert has_element?(view, "#nav-record", "Record measurement")
      assert has_element?(view, "#nav-register", "Register project")
    end
  end

  describe "app/1 — breadcrumbs slot" do
    test "breadcrumbs nav is absent when the slot is not provided", %{conn: conn} do
      # The dashboard LiveView does not supply :breadcrumbs, so the nav#breadcrumbs
      # element must not appear — this proves the :if={@breadcrumbs != []} guard.
      {:ok, view, _html} = live(conn, ~p"/")
      refute has_element?(view, "#breadcrumbs")
    end

    test "breadcrumbs nav renders and contains slot content when slot is populated" do
      html =
        render_component(&LivedataWeb.Layouts.app/1, %{
          flash: %{},
          max_width: "max-w-2xl",
          inner_block: [
            %{__slot__: :inner_block, inner_block: fn _, _ -> "Page body" end}
          ],
          breadcrumbs: [
            %{__slot__: :breadcrumbs, inner_block: fn _, _ -> "Home / Projects" end}
          ]
        })

      assert html =~ ~s(id="breadcrumbs")
      assert html =~ "Home / Projects"
    end
  end
end
