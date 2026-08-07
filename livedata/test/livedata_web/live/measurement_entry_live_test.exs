defmodule LivedataWeb.MeasurementEntryLiveTest do
  use LivedataWeb.ConnCase, async: false

  @moduletag :integration

  import Phoenix.LiveViewTest

  alias Livedata.Repo
  alias Livedata.Measurements.RawMeasurement
  alias Livedata.Projects.{Project, Activity}

  defp activity_id! do
    project =
      %Project{}
      |> Project.changeset(%{
        name: "P",
        status: "DRAFT",
        commissioned_at: DateTime.utc_now()
      })
      |> Repo.insert!()

    activity =
      %Activity{}
      |> Activity.changeset(project.id, %{
        name: "A",
        activity_type: "PERMANENT_REMOVAL",
        status: "REGISTERED",
        activity_period_start: ~D[2026-01-01],
        monitoring_period_start: ~D[2025-12-01]
      })
      |> Repo.insert!()

    activity.id
  end

  defp params(aid) do
    %{
      "measurement" => %{
        "activity_id" => aid,
        "measured_at" => "2026-07-01T10:00",
        "provenance_json" =>
          ~s({"method":"core","latitude":45.1,"longitude":7.6,"crs":"EPSG:4326"}),
        "values_json" => ~s({"soc":2.3})
      }
    }
  end

  test "renders the entry form", %{conn: conn} do
    activity_id!()
    {:ok, view, _html} = live(conn, ~p"/measurements/new")
    assert has_element?(view, "#measurement-entry-form select[name='measurement[activity_id]']")
    assert has_element?(view, "textarea[name='measurement[values_json]']")
  end

  test "a valid submission creates a raw measurement", %{conn: conn} do
    aid = activity_id!()
    {:ok, view, _} = live(conn, ~p"/measurements/new")
    render_submit(element(view, "#measurement-entry-form"), params(aid))
    assert Repo.aggregate(RawMeasurement, :count) == 1
  end

  test "a duplicate submission is rejected and not written twice", %{conn: conn} do
    aid = activity_id!()
    {:ok, view, _} = live(conn, ~p"/measurements/new")
    render_submit(element(view, "#measurement-entry-form"), params(aid))
    render_submit(element(view, "#measurement-entry-form"), params(aid))
    assert Repo.aggregate(RawMeasurement, :count) == 1
  end
end
