defmodule LivedataWeb.MeasurementEntryLiveTest do
  use LivedataWeb.ConnCase, async: false

  @moduletag :integration

  import Phoenix.LiveViewTest
  import Livedata.Fixtures

  alias Livedata.Measurements.RawMeasurement
  alias Livedata.Repo

  defp params(activity_id, overrides \\ %{}) do
    %{
      "measurement" =>
        Map.merge(
          %{
            "activity_id" => activity_id,
            "measured_at" => "2026-07-01T10:00",
            "method" => "core",
            "latitude" => "45.1",
            "longitude" => "7.6",
            "crs" => "EPSG:4326",
            "values" => %{"0" => %{"key" => "soc", "value" => "2.3"}}
          },
          overrides
        )
    }
  end

  describe "unscoped entry" do
    test "renders the activity picker and structured provenance fields", %{conn: conn} do
      portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/measurements/new")

      assert has_element?(view, "#measurement-entry-form select[name='measurement[activity_id]']")
      # @req: CRCF-16 — provenance is fields, not a JSON blob.
      assert has_element?(view, "#coordinates input[name='measurement[latitude]']")
      assert has_element?(view, "#coordinates input[name='measurement[longitude]']")
      assert has_element?(view, "#coordinates select[name='measurement[crs]']")
      assert has_element?(view, "input[name='measurement[method]']")
      assert has_element?(view, "#values-repeater")
      assert has_element?(view, "#use-my-location")
      refute has_element?(view, "#entry-context")
    end

    test "a valid submission creates a raw measurement with full provenance", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/measurements/new")
      render_submit(element(view, "#measurement-entry-form"), params(activity.id))

      assert [measurement] = Repo.all(RawMeasurement)
      assert measurement.activity_id == activity.id
      assert measurement.provenance["method"] == "core"
      assert measurement.provenance["crs"] == "EPSG:4326"
      # The repeater's numeric strings are stored as numbers.
      assert measurement.values == %{"soc" => 2.3}
    end

    # @req: CRCF-28
    test "a duplicate submission is rejected with a specific message", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/measurements/new")
      render_submit(element(view, "#measurement-entry-form"), params(activity.id))
      html = render_submit(element(view, "#measurement-entry-form"), params(activity.id))

      assert Repo.aggregate(RawMeasurement, :count) == 1
      assert html =~ "identical reading"
      assert html =~ "provenance is not part of the duplicate check"
    end

    # @req: CRCF-38
    test "an out-of-range latitude is reported on the field", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/measurements/new")

      html =
        render_submit(
          element(view, "#measurement-entry-form"),
          params(activity.id, %{"latitude" => "120"})
        )

      assert html =~ "must be less than or equal to 90"
      assert Repo.aggregate(RawMeasurement, :count) == 0
    end

    test "submitting with no values reports the payload error", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/measurements/new")

      html =
        render_submit(
          element(view, "#measurement-entry-form"),
          params(activity.id, %{"values" => %{"0" => %{"key" => "", "value" => ""}}})
        )

      assert has_element?(view, "#values-error")
      assert html =~ "at least one value"
      assert Repo.aggregate(RawMeasurement, :count) == 0
    end
  end

  describe "values repeater" do
    test "adds and removes rows", %{conn: conn} do
      portfolio_fixture()
      {:ok, view, _html} = live(conn, ~p"/measurements/new")

      assert has_element?(view, "#remove-value-0")
      refute has_element?(view, "#remove-value-1")

      render_click(element(view, "#add-value"))
      assert has_element?(view, "#remove-value-1")

      render_click(element(view, "#remove-value-1"))
      refute has_element?(view, "#remove-value-1")
    end

    test "toggles to a raw JSON editor and back", %{conn: conn} do
      portfolio_fixture()
      {:ok, view, _html} = live(conn, ~p"/measurements/new")

      render_click(element(view, "#toggle-raw-json"))
      assert has_element?(view, "textarea[name='measurement[values_json]']")
      refute has_element?(view, "#values-repeater")

      render_click(element(view, "#toggle-raw-json"))
      assert has_element?(view, "#values-repeater")
    end

    test "a raw JSON payload is accepted", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()
      {:ok, view, _html} = live(conn, ~p"/measurements/new")
      render_click(element(view, "#toggle-raw-json"))

      render_submit(
        element(view, "#measurement-entry-form"),
        params(activity.id, %{"values_json" => ~s({"biomass":12})})
      )

      assert [measurement] = Repo.all(RawMeasurement)
      assert measurement.values == %{"biomass" => 12}
    end
  end

  describe "scoped entry" do
    test "pre-selects the activity and shows its context", %{conn: conn} do
      %{project: project, activity: activity} = portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/measurements/new?activity_id=#{activity.id}")

      assert has_element?(view, "#entry-context", project.name)
      assert has_element?(view, "#entry-context", activity.name)
      assert has_element?(view, "#entry-context", "Last measurement never")
      refute has_element?(view, "select[name='measurement[activity_id]']")
      assert has_element?(view, "#breadcrumbs", activity.name)
    end

    # UC-2 — a campaign is many readings at one site.
    test "keeps the site after a save and lists what was recorded", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/measurements/new?activity_id=#{activity.id}")
      render_submit(element(view, "#measurement-entry-form"), params(activity.id))

      assert [measurement] = Repo.all(RawMeasurement)
      assert has_element?(view, "#session-recorded #recorded-#{measurement.id}")

      html = render(view)
      # method and coordinates survive for the next reading
      assert html =~ ~s(value="core")
      assert html =~ ~s(value="45.1")
    end
  end
end
