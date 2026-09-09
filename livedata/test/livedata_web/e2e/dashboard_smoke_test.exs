defmodule LivedataWeb.E2e.DashboardSmokeTest do
  use LivedataWeb.WallabyCase, async: false

  @tag :e2e
  feature "dashboard shows a project inserted by the test setup", %{session: session} do
    project = project_fixture(%{name: "E2E Smoke Project"})

    session
    |> visit("/")
    |> assert_has(css("#project-card-#{project.id}", text: project.name))
  end
end
