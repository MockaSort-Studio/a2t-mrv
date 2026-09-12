defmodule LivedataWeb.E2E.MeasurementUploadTest do
  @moduledoc """
  Browser-level specs for the bulk CSV upload flow.

  These target client-side behaviours that Phoenix.LiveViewTest cannot observe:
  select option state after phx-change re-render, per-entry upload error rendering,
  LiveView stability on submit-during-upload, and the full developer spine.
  """

  use LivedataWeb.E2ECase, async: false

  @moduletag :e2e

  # ---------------------------------------------------------------------------
  # Spec 1 — activity selection survives file attachment
  #
  # Baseline behaviour at 02b851e: the validate handler ignored params, so
  # options carried no `selected` attribute on re-render. LiveView's DOM patcher
  # cleared the browser selection on every validate event, making the select
  # revert to blank when a file was chosen. Import then ran with empty activity_id.
  # @req: CRCF-27
  # ---------------------------------------------------------------------------

  feature "activity selection is preserved after file attachment", %{session: session} do
    %{project: project, activity: activity} = portfolio_fixture()
    option_label = "#{project.name} — #{activity.name}"
    csv_path = temp_csv("activity_select_#{System.unique_integer([:positive])}.csv", valid_csv())

    session
    |> visit("/measurements/upload")
    |> find(css("#activity-select"), fn el ->
      click(el, option(option_label))
    end)
    |> attach_file(css("input[type=file]"), path: csv_path)
    |> click(button("Import file"))
    |> assert_has(css("#upload-result"))
  end

  # ---------------------------------------------------------------------------
  # Spec 2a — oversized file shows rejection message
  #
  # Baseline behaviour at 02b851e: upload_errors/2 was never called per entry,
  # so :too_large errors were never rendered. The button stayed active; clicking
  # it with a rejected entry crashed the LiveView.
  # @req: CRCF-38
  # ---------------------------------------------------------------------------

  feature "oversized file shows rejection message", %{session: session} do
    %{activity: activity} = portfolio_fixture()

    oversized_path =
      temp_csv(
        "too_large_#{System.unique_integer([:positive])}.csv",
        String.duplicate("x", 5_000_001)
      )

    session
    |> visit("/measurements/upload?activity_id=#{activity.id}")
    |> attach_file(css("input[type=file]"), path: oversized_path)
    |> assert_has(css("p.text-error", text: "File too large"))
  end

  # ---------------------------------------------------------------------------
  # Spec 2b — non-CSV file shows rejection message
  #
  # Baseline behaviour at 02b851e: same as 2a — upload_errors/2 not called,
  # :not_accepted error never rendered.
  # @req: CRCF-38
  # ---------------------------------------------------------------------------

  feature "non-CSV file shows rejection message", %{session: session} do
    %{activity: activity} = portfolio_fixture()
    xlsx_path = temp_file("data_#{System.unique_integer([:positive])}.xlsx", "binary content")

    session
    |> visit("/measurements/upload?activity_id=#{activity.id}")
    |> attach_file(css("input[type=file]"), path: xlsx_path)
    |> assert_has(css("p.text-error", text: "Only CSV files are accepted"))
  end

  # ---------------------------------------------------------------------------
  # Spec 3 — submit during upload does not crash the page
  #
  # Baseline behaviour at 02b851e: consume_uploaded_entries/3 was called
  # unconditionally and raised for any entry with done? == false, taking the
  # LiveView down. In Chrome, LiveView's JS may block the submit while an entry
  # is in-flight; this spec asserts the page remains stable either way.
  # ---------------------------------------------------------------------------

  feature "submitting during upload does not crash the page", %{session: session} do
    %{activity: activity} = portfolio_fixture()
    csv_path = temp_csv("inflight_#{System.unique_integer([:positive])}.csv", valid_csv())

    session
    |> visit("/measurements/upload?activity_id=#{activity.id}")
    |> attach_file(css("input[type=file]"), path: csv_path)
    |> click(button("Import file"))
    |> assert_has(css("#upload-form"))
  end

  # ---------------------------------------------------------------------------
  # Spec 4 — developer spine
  #
  # Full journey: use fixtures for DB state, navigate from activity workbench
  # to the upload page via the "Upload file" link, import a valid CSV, and
  # confirm the measurement row is visible in the activity's table.
  # @req: CRCF-27, CRCF-16
  # ---------------------------------------------------------------------------

  feature "spine: navigate from activity to upload, import CSV, row visible in table",
          %{session: session} do
    %{activity: activity} = portfolio_fixture()
    csv_path = temp_csv("spine_#{System.unique_integer([:positive])}.csv", valid_csv())

    session
    |> visit("/activities/#{activity.id}")
    |> click(css("#activity-upload-link"))
    |> attach_file(css("input[type=file]"), path: csv_path)
    |> click(button("Import file"))
    |> assert_has(css("#upload-result"))
    |> visit("/activities/#{activity.id}")
    |> assert_has(css("#measurements-count", text: "Showing 1"))
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

  defp temp_csv(filename, content), do: temp_file(filename, content)

  defp temp_file(filename, content) do
    path = Path.join(System.tmp_dir!(), filename)
    File.write!(path, content)
    path
  end
end
