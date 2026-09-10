defmodule LivedataWeb.E2E.SmokeTest do
  @moduledoc """
  Smoke spec: browser reaches the dashboard and sees data inserted by its own setup.
  """

  use LivedataWeb.E2ECase, async: false

  @moduletag :e2e

  import Wallaby.Query

  feature "dashboard shows a project inserted by setup", %{session: session} do
    project = project_fixture(%{name: "Smoke Test Project"})

    session
    |> visit("/")
    |> assert_has(css("#project-card-#{project.id}"))
  end
end
