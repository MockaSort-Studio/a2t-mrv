defmodule A2tMrvWeb.ErrorJSONTest do
  use A2tMrvWeb.ConnCase, async: true

  test "renders 404" do
    assert A2tMrvWeb.ErrorJSON.render("404.json", %{}) == %{errors: %{detail: "Not Found"}}
  end

  test "renders 500" do
    assert A2tMrvWeb.ErrorJSON.render("500.json", %{}) ==
             %{errors: %{detail: "Internal Server Error"}}
  end
end
