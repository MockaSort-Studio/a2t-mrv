defmodule LivedataWeb.PageControllerTest do
  use LivedataWeb.ConnCase, async: true

  test "GET / renders the dashboard", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "Your projects"
  end
end
