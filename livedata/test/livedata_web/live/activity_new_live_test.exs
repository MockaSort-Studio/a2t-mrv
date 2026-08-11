defmodule LivedataWeb.ActivityNewLiveTest do
  use LivedataWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Livedata.Fixtures

  alias Livedata.Projects
  alias Livedata.Projects.Methodology
  alias Livedata.Repo

  defp methodology do
    Repo.insert!(
      Methodology.changeset(%Methodology{}, %{
        name: "M#{System.unique_integer([:positive])}"
      })
    )
  end

  defp valid_params(overrides \\ %{}) do
    Map.merge(
      %{
        "activity_name" => "Soil sampling",
        "activity_type" => "PERMANENT_REMOVAL",
        "activity_period_start" => "2026-01-01",
        "monitoring_period_start" => "2025-12-01",
        "methodology_ids" => [methodology().id]
      },
      overrides
    )
  end

  test "renders the activity fields", %{conn: conn} do
    project = project_fixture()

    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}/activities/new")

    assert has_element?(view, "#add-activity-form #activity-fields")
    assert has_element?(view, "select[name='activity[activity_type]']")
    assert has_element?(view, "select[name='activity[methodology_ids][]']")
    assert has_element?(view, "#breadcrumbs", project.name)
  end

  # @req: CRCF-14 — tier is derived, and permanent removal has no end dates.
  test "shows the derived tier and hides end dates for permanent removal", %{conn: conn} do
    project = project_fixture()
    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}/activities/new")

    render_change(element(view, "#add-activity-form"), %{
      "activity" => valid_params(%{"activity_type" => "PERMANENT_REMOVAL"})
    })

    assert has_element?(view, "#derived-tier", "PERMANENT")
    assert has_element?(view, "#permanent-note")
    refute has_element?(view, "input[name='activity[activity_period_end]']")
  end

  test "shows end dates and the FARMING tier for a farming activity", %{conn: conn} do
    project = project_fixture()
    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}/activities/new")

    render_change(element(view, "#add-activity-form"), %{
      "activity" => valid_params(%{"activity_type" => "FARMING_SEQUESTRATION"})
    })

    assert has_element?(view, "#derived-tier", "FARMING")
    assert has_element?(view, "input[name='activity[activity_period_end]']")
    refute has_element?(view, "#permanent-note")
  end

  # @req: CRCF-34
  test "submitting adds the activity to the project and redirects to it", %{conn: conn} do
    project = project_fixture()
    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}/activities/new")

    assert {:error, {:live_redirect, %{to: to}}} =
             render_submit(element(view, "#add-activity-form"), %{"activity" => valid_params()})

    assert to == "/projects/#{project.id}"

    assert [activity] = Projects.list_activities_with_stats(project_id: project.id)
    assert activity.name == "Soil sampling"
    assert activity.storage_duration_tier == "PERMANENT"
  end

  # @req: CRCF-38
  test "a missing name is reported on the field", %{conn: conn} do
    project = project_fixture()
    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}/activities/new")

    html =
      render_submit(element(view, "#add-activity-form"), %{
        "activity" => valid_params(%{"activity_name" => ""})
      })

    assert html =~ "can&#39;t be blank"
    assert Projects.list_activities_with_stats(project_id: project.id) == []
  end

  # @req: CRCF-35
  test "at least one methodology is required", %{conn: conn} do
    project = project_fixture()
    {:ok, view, _html} = live(conn, ~p"/projects/#{project.id}/activities/new")

    html =
      render_submit(element(view, "#add-activity-form"), %{
        "activity" => valid_params(%{"methodology_ids" => []})
      })

    assert html =~ "select at least one methodology"
    assert Projects.list_activities_with_stats(project_id: project.id) == []
  end
end
