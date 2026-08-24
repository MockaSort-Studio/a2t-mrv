defmodule LivedataWeb.LayoutsTest do
  use LivedataWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  test "primary nav renders and breadcrumbs absent without slot", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, "#nav-dashboard", "Dashboard")
    assert has_element?(view, "#nav-record", "Record measurement")
    assert has_element?(view, "#nav-register", "Register project")
    refute has_element?(view, "#breadcrumbs")
  end

  test "breadcrumbs slot renders when populated" do
    html =
      render_component(&LivedataWeb.Layouts.app/1, %{
        flash: %{},
        max_width: "max-w-2xl",
        inner_block: [%{__slot__: :inner_block, inner_block: fn _, _ -> "body" end}],
        breadcrumbs: [%{__slot__: :breadcrumbs, inner_block: fn _, _ -> "Home / Projects" end}]
      })

    assert html =~ ~s(id="breadcrumbs")
    assert html =~ "Home / Projects"
  end
end
