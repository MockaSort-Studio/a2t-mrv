defmodule LivedataWeb.MeasurementUploadLiveTest do
  use LivedataWeb.ConnCase, async: false

  @moduletag :integration

  import Phoenix.LiveViewTest
  import Livedata.Fixtures

  alias Livedata.Measurements.RawMeasurement
  alias Livedata.Repo

  defp valid_csv_content do
    """
    measured_at,method,latitude,longitude,crs,values_json
    2026-07-01T10:00:00Z,core,45.1,7.6,EPSG:4326,{"soc":2.3}
    2026-07-02T10:00:00Z,core,45.2,7.7,EPSG:4326,{"soc":3.1}
    """
  end

  defp invalid_csv_content do
    """
    measured_at,method,latitude,longitude,crs,values_json
    bad-date,,999,7.6,EPSG:4326,{"soc":2.3}
    """
  end

  describe "mount and render" do
    test "renders the upload form with activity picker", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()
      _ = activity

      {:ok, view, _html} = live(conn, ~p"/measurements/upload")

      assert has_element?(view, "#upload-form")
      assert has_element?(view, "select[name='activity_id']")
    end

    test "scopes to activity when activity_id query param given", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()

      {:ok, view, html} = live(conn, ~p"/measurements/upload?activity_id=#{activity.id}")

      assert html =~ activity.name
      refute has_element?(view, "select[name='activity_id']")
    end
  end

  describe "successful upload" do
    # @req: CRCF-27 — all rows inserted on a valid file
    test "inserts all rows and shows success flash", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/measurements/upload?activity_id=#{activity.id}")

      view
      |> file_input("#upload-form", :csv_file, [
        %{name: "data.csv", content: valid_csv_content(), type: "text/csv"}
      ])
      |> render_upload("data.csv")

      html = render_submit(view, "upload", %{"activity_id" => activity.id})

      assert html =~ "2 measurements"
      assert Repo.aggregate(RawMeasurement, :count) == 2
    end
  end

  describe "validation errors" do
    # @req: CRCF-27 — invalid file → zero rows written
    test "writes nothing and shows per-row errors for an invalid file", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()

      {:ok, view, _html} = live(conn, ~p"/measurements/upload?activity_id=#{activity.id}")

      view
      |> file_input("#upload-form", :csv_file, [
        %{name: "bad.csv", content: invalid_csv_content(), type: "text/csv"}
      ])
      |> render_upload("bad.csv")

      html = render_submit(view, "upload", %{"activity_id" => activity.id})

      assert Repo.aggregate(RawMeasurement, :count) == 0
      assert has_element?(view, "#upload-errors")
      assert html =~ "Row 1"
    end

    # @req: CRCF-28 — batch-internal duplicate
    test "rejects a file with two identical rows", %{conn: conn} do
      %{activity: activity} = portfolio_fixture()

      dup_csv = """
      measured_at,method,latitude,longitude,crs,values_json
      2026-07-01T10:00:00Z,core,45.1,7.6,EPSG:4326,{"soc":2.3}
      2026-07-01T10:00:00Z,core,45.1,7.6,EPSG:4326,{"soc":2.3}
      """

      {:ok, view, _html} = live(conn, ~p"/measurements/upload?activity_id=#{activity.id}")

      view
      |> file_input("#upload-form", :csv_file, [
        %{name: "dup.csv", content: dup_csv, type: "text/csv"}
      ])
      |> render_upload("dup.csv")

      html = render_submit(view, "upload", %{"activity_id" => activity.id})

      assert Repo.aggregate(RawMeasurement, :count) == 0
      assert html =~ "duplicate"
    end
  end
end
