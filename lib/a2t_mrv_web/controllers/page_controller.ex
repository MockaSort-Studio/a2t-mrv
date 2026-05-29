defmodule A2tMrvWeb.PageController do
  use A2tMrvWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
