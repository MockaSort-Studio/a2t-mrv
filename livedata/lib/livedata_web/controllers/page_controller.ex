defmodule LivedataWeb.PageController do
  use LivedataWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
