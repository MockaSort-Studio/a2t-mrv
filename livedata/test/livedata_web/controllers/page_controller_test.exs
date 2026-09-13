defmodule LivedataWeb.PageControllerTest do
  use LivedataWeb.ConnCase, async: true

  test "GET / renders the dashboard", %{conn: conn} do
    conn = conn |> log_in_user() |> get(~p"/")
    assert html_response(conn, 200) =~ "Your portfolio"
  end
end
