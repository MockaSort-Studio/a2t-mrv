defmodule LivedataWeb.MeasurementUploadLiveFeedbackTest do
  use LivedataWeb.ConnCase, async: false

  @moduletag :integration

  import Phoenix.LiveViewTest
  import Livedata.Fixtures

  # ---------------------------------------------------------------------------
  # Per-entry upload errors (too_large, not_accepted)
  # ---------------------------------------------------------------------------

  # @req: CRCF-38
  test "oversized file shows error message instead of silent failure", %{conn: conn} do
    %{activity: activity} = portfolio_fixture()
    {:ok, view, _html} = live(conn, ~p"/measurements/upload?activity_id=#{activity.id}")

    oversized_content = String.duplicate("a", 5_000_001)

    view
    |> file_input("#upload-form", :csv_file, [
      %{name: "big.csv", content: oversized_content, type: "text/csv", size: 5_000_001}
    ])
    |> render_upload("big.csv", 100)

    html = render(view)
    assert html =~ "too large" or html =~ "File too large"
  end

  test "non-CSV file shows error message", %{conn: conn} do
    %{activity: activity} = portfolio_fixture()
    {:ok, view, _html} = live(conn, ~p"/measurements/upload?activity_id=#{activity.id}")

    view
    |> file_input("#upload-form", :csv_file, [
      %{name: "data.xlsx", content: "binary", type: "application/vnd.openxmlformats"}
    ])
    |> render_upload("data.xlsx", 100)

    html = render(view)
    assert html =~ "CSV" or html =~ "not accepted" or html =~ "Only CSV"
  end

  # ---------------------------------------------------------------------------
  # Activity selection preserved when file is selected after activity
  # ---------------------------------------------------------------------------

  test "activity selection is preserved when file is selected afterward", %{conn: conn} do
    %{activity: activity} = portfolio_fixture()
    {:ok, view, _html} = live(conn, ~p"/measurements/upload")

    # Select the activity first
    render_change(view, "validate", %{"activity_id" => activity.id})

    # Then select a file (fires another validate event with activity_id in params)
    view
    |> file_input("#upload-form", :csv_file, [
      %{
        name: "data.csv",
        content: valid_csv(),
        type: "text/csv"
      }
    ])
    |> render_upload("data.csv")

    html = render(view)

    assert has_element?(view, "option[value='#{activity.id}'][selected]"),
           "Activity selection was lost after file selection. HTML: #{html}"
  end

  # ---------------------------------------------------------------------------
  # Flash cleared on failure
  # ---------------------------------------------------------------------------

  test "a stale success flash is cleared when the next upload fails", %{conn: conn} do
    %{activity: activity} = portfolio_fixture()
    {:ok, view, _html} = live(conn, ~p"/measurements/upload?activity_id=#{activity.id}")

    # First upload: success
    view
    |> file_input("#upload-form", :csv_file, [
      %{name: "good.csv", content: valid_csv(), type: "text/csv"}
    ])
    |> render_upload("good.csv")

    render_submit(view, "upload", %{"activity_id" => activity.id})

    # Second upload: failure
    view
    |> file_input("#upload-form", :csv_file, [
      %{name: "bad.csv", content: invalid_csv(), type: "text/csv"}
    ])
    |> render_upload("bad.csv")

    html = render_submit(view, "upload", %{"activity_id" => activity.id})

    refute html =~ "measurements imported",
           "Stale success flash still visible alongside error: #{html}"

    assert has_element?(view, "#upload-errors")
  end

  # ---------------------------------------------------------------------------
  # One error per form problem — blank activity_id is a form error, not a CSV error
  # ---------------------------------------------------------------------------

  test "blank activity_id produces exactly one error, not one per row", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/measurements/upload")

    csv = """
    measured_at,method,latitude,longitude,crs,values_json
    2026-07-01T10:00:00Z,core,45.1,7.6,EPSG:4326,{"soc":1.0}
    2026-07-02T10:00:00Z,core,45.2,7.7,EPSG:4326,{"soc":2.0}
    2026-07-03T10:00:00Z,core,45.3,7.8,EPSG:4326,{"soc":3.0}
    """

    view
    |> file_input("#upload-form", :csv_file, [
      %{name: "data.csv", content: csv, type: "text/csv"}
    ])
    |> render_upload("data.csv")

    html = render_submit(view, "upload", %{"activity_id" => ""})

    assert has_element?(view, "#upload-errors"),
           "Expected upload-errors to be visible. HTML: #{html}"

    error_items =
      html
      |> String.split("<li")
      |> length()
      |> Kernel.-(1)

    assert error_items == 1,
           "Expected exactly 1 error item for blank activity_id on 3-row file, got #{error_items}. HTML: #{html}"
  end

  # ---------------------------------------------------------------------------
  # Pluralization
  # ---------------------------------------------------------------------------

  test "success message uses singular for exactly one row", %{conn: conn} do
    %{activity: activity} = portfolio_fixture()
    {:ok, view, _html} = live(conn, ~p"/measurements/upload?activity_id=#{activity.id}")

    single_row_csv = """
    measured_at,method,latitude,longitude,crs,values_json
    2026-07-01T10:00:00Z,core,45.1,7.6,EPSG:4326,{"soc":1.0}
    """

    view
    |> file_input("#upload-form", :csv_file, [
      %{name: "one.csv", content: single_row_csv, type: "text/csv"}
    ])
    |> render_upload("one.csv")

    html = render_submit(view, "upload", %{"activity_id" => activity.id})

    assert html =~ "1 measurement imported",
           "Expected singular '1 measurement imported', got: #{html}"

    refute html =~ "1 measurements imported",
           "Got incorrectly pluralized '1 measurements imported': #{html}"
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp valid_csv do
    """
    measured_at,method,latitude,longitude,crs,values_json
    2026-07-01T10:00:00Z,core,45.1,7.6,EPSG:4326,{"soc":2.3}
    """
  end

  defp invalid_csv do
    """
    measured_at,method,latitude,longitude,crs,values_json
    bad-date,,999,7.6,EPSG:4326,{"soc":2.3}
    """
  end
end
