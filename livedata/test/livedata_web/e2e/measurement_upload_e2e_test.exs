defmodule LivedataWeb.E2e.MeasurementUploadTest do
  use LivedataWeb.WallabyCase, async: false

  alias Livedata.Projects.Methodology
  alias Livedata.Repo

  # CSV helpers

  defp valid_csv_content do
    """
    measured_at,method,latitude,longitude,crs,values_json
    2026-01-01T10:00:00Z,core,45.1,7.6,EPSG:4326,"{""soc"":2.3}"
    """
  end

  defp write_csv(content, name) do
    path = Path.join(System.tmp_dir!(), name)
    File.write!(path, content)
    path
  end

  # Spec 1 — Activity selection is preserved after choosing a file.
  #
  # RED baseline (02b851e): the validate handler ignored params and the template
  # had no `selected` attribute on options, so LiveView's DOM patcher cleared
  # the browser selection on every validate re-render. Submitting after file
  # selection then sent an empty activity_id, producing a context lookup error.
  @tag :e2e
  feature "activity selection survives choosing a file", %{session: session} do
    %{project: project, activity: activity} = portfolio_fixture()
    label = "#{project.name} — #{activity.name}"
    csv_path = write_csv(valid_csv_content(), "spec1_activity_select.csv")

    session
    |> visit("/measurements/upload")
    |> find(css("#activity-select"), fn sel ->
      sel |> click(option(label))
    end)
    |> attach_file(css("input[type='file']"), path: csv_path)
    |> click(css("button[type='submit']"))
    # Success: the activity ID was preserved through the validate re-render.
    |> assert_has(css("#upload-result"))
  end

  # Spec 2a — A file over the 5 MB cap is rejected with a human reason.
  #
  # RED baseline (02b851e): upload_errors/2 was never called per entry, so
  # per-entry errors (:too_large) were not rendered; the UI gave no feedback.
  @tag :e2e
  feature "a file over 5 MB is rejected with its reason", %{session: session} do
    large_path = write_csv(String.duplicate("x,", 2_600_000), "spec2a_large.csv")

    session
    |> visit("/measurements/upload")
    |> attach_file(css("input[type='file']"), path: large_path)
    |> assert_has(css("p.text-error", text: "File too large"))
  end

  # Spec 2b — A non-CSV file is rejected with a human reason.
  #
  # RED baseline (02b851e): same per-entry error omission as spec 2a.
  @tag :e2e
  feature "a non-CSV file is rejected with its reason", %{session: session} do
    bad_path = write_csv("this is not a csv", "spec2b_bad.pdf")

    session
    |> visit("/measurements/upload")
    |> attach_file(css("input[type='file']"), path: bad_path)
    |> assert_has(css("p.text-error", text: "Only CSV files are accepted"))
  end

  # Spec 3 — Clicking "Import file" while an upload is in flight does not
  # crash the LiveView.
  #
  # RED baseline (02b851e): the upload handler called consume_uploaded_entries/3
  # unconditionally; that function raises for entries that are not done?, which
  # crashed the LiveView. In Chrome, LiveView's JS may shield the submit while
  # an entry is still uploading — see #127 for the observed pre-fix behaviour.
  # This spec is a guard: whatever path the browser takes, the page must stay
  # connected and present the form.
  @tag :e2e
  feature "clicking import while upload is in flight does not crash the page", %{session: session} do
    csv_path = write_csv(valid_csv_content(), "spec3_inflight.csv")

    session
    |> visit("/measurements/upload")
    |> attach_file(css("input[type='file']"), path: csv_path)
    # Attempt submit immediately after attaching. Two outcomes are valid:
    # (a) LiveView JS shields the submit (entry still uploading) → form stays.
    # (b) Upload completes before click; server handles it → result or error.
    # Either way the WebSocket must remain connected.
    |> click(css("button[type='submit']"))
    |> assert_has(css("#upload-form"))
  end

  # Spec 4 — Spine: visit activity page → follow "Upload file" → import a
  # valid CSV → row appears in the activity's measurement table.
  @tag :e2e
  feature "spine: upload CSV and see measurement in activity table", %{session: session} do
    %{activity: activity} = portfolio_fixture()
    csv_path = write_csv(valid_csv_content(), "spec4_spine.csv")

    session
    |> visit("/activities/#{activity.id}")
    |> click(css("#activity-upload-link"))
    # The link navigates to /measurements/upload?activity_id=<id>,
    # which shows a hidden input — no activity picker visible.
    |> attach_file(css("input[type='file']"), path: csv_path)
    |> click(css("button[type='submit']"))
    |> assert_has(css("#upload-result"))
    # Navigate back to the activity page and verify the imported row.
    |> visit("/activities/#{activity.id}")
    |> assert_has(css("tr[id^='measurements-']"))
  end
end
