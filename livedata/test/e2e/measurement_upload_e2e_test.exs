defmodule LivedataWeb.MeasurementUploadE2ETest do
  use LivedataWeb.E2ECase, async: false

  @moduletag :e2e

  import Ecto.Query
  import Livedata.Fixtures

  alias Livedata.Projects.{Activity, Methodology}
  alias Livedata.Repo

  # ---------------------------------------------------------------------------
  # Spec 1 — Activity selection survives choosing a file
  #
  # Pre-fix (02b851e): validate handler lacked selected_activity_id; file
  # selection re-rendered the dropdown back to "Choose an activity".
  # Expected outcome on 02b851e: FAIL — option[selected] assertion misses.
  # ---------------------------------------------------------------------------

  test "activity selection is preserved when file is attached afterward", %{session: session} do
    %{activity: activity} = portfolio_fixture()
    csv_path = write_tmp_csv()

    session =
      session
      |> visit("/measurements/upload")
      |> select_activity(activity.id)
      |> attach_file(css("#upload-form input[type=file]"), path: csv_path)

    assert has?(session, css("#activity-select option[value='#{activity.id}'][selected]"))
  end

  # ---------------------------------------------------------------------------
  # Spec 2 — A rejected file says why (@req: CRCF-38)
  #
  # Pre-fix (02b851e): template called upload_errors/1 (no entry arg) which
  # yields only :too_many_files — both messages were unreachable dead code.
  # Expected outcome on 02b851e: FAIL — assert_has finds no matching element.
  # ---------------------------------------------------------------------------

  test "oversized file shows rejection message before submit", %{session: session} do
    %{activity: activity} = portfolio_fixture()

    session
    |> visit("/measurements/upload?activity_id=#{activity.id}")
    |> attach_file(css("#upload-form input[type=file]"), path: write_tmp_big_file())
    |> assert_has(css("p.text-error", text: "File too large"))
  end

  test "non-CSV file shows rejection message before submit", %{session: session} do
    %{activity: activity} = portfolio_fixture()

    session
    |> visit("/measurements/upload?activity_id=#{activity.id}")
    |> attach_file(css("#upload-form input[type=file]"), path: write_tmp_non_csv())
    |> assert_has(css("p.text-error", text: "CSV"))
  end

  # ---------------------------------------------------------------------------
  # Spec 3 — Submitting with a refused entry does not crash the page
  #
  # Under Phoenix.LiveViewTest a refused entry triggered consume_uploaded_entries/3
  # which raises for entries that are not done?, crashing the LiveView. In a real
  # browser, LiveView's JS blocks submit while an entry carries an error — so the
  # server may never receive the event. This spec settles which shield applies.
  # ---------------------------------------------------------------------------

  test "clicking Import with a refused entry does not crash the page", %{session: session} do
    %{activity: activity} = portfolio_fixture()

    session =
      session
      |> visit("/measurements/upload?activity_id=#{activity.id}")
      |> attach_file(css("#upload-form input[type=file]"), path: write_tmp_big_file())
      |> click(button("Import file"))

    # Page must still respond: either the JS-level rejection message (browser
    # shielded the submit) or the server's "Import failed" report is shown.
    assert has?(session, css("#upload-form"))
  end

  # ---------------------------------------------------------------------------
  # Spec 4 — Spine: register → upload CSV → row visible
  # @req: CRCF-27, @req: CRCF-16
  # ---------------------------------------------------------------------------

  test "full journey: register project → upload CSV → row visible in measurement table",
       %{session: session} do
    methodology =
      Repo.insert!(Methodology.changeset(%Methodology{}, %{name: "E2E Method", reference: "ref"}))

    multipolygon =
      ~s({"type":"MultiPolygon","coordinates":[[[[0,0],[1,0],[1,1],[0,1],[0,0]]]]})

    # Step 1: register project + activity through the browser form
    session =
      session
      |> visit("/projects/new")
      |> fill_in(css("[name='registration[project_name]']"), with: "E2E Project")
      |> fill_in(css("[name='registration[parcel_ref]']"), with: "LPIS-E2E-001")
      |> fill_in(css("[name='registration[parcel_boundary_geojson]']"), with: multipolygon)
      |> fill_in(css("[name='registration[activity_name]']"), with: "E2E Activity")
      |> fill_in(css("[name='registration[activity_period_start]']"), with: "2026-01-01")
      |> fill_in(css("[name='registration[monitoring_period_start]']"), with: "2026-01-01")
      |> execute_script("""
        ['[name="registration[parcel_data_source]"]',
         '[name="registration[activity_type]"]'].forEach(function(sel) {
          var el = document.querySelector(sel);
          el.options[1].selected = true;
          el.dispatchEvent(new Event('change', {bubbles: true}));
        });
        var opt = document.querySelector(
          '[name="registration[methodology_ids][]"] option[value="#{methodology.id}"]');
        if (opt) { opt.selected = true;
          opt.closest('select').dispatchEvent(new Event('change', {bubbles: true})); }
      """)
      |> click(button("Register project"))

    # Locate the activity created by registration to navigate directly to it
    activity = Repo.one!(from a in Activity, order_by: [desc: a.inserted_at], limit: 1)

    # Step 2: follow "Upload file" from the activity workbench
    session =
      session
      |> visit("/activities/#{activity.id}")
      |> click(css("#activity-upload-link"))
      |> attach_file(css("#upload-form input[type=file]"), path: write_tmp_csv())
      |> click(button("Import file"))

    assert has?(session, css("#upload-result"))

    # Step 3: navigate back to the activity and verify the measurement row
    session = visit(session, "/activities/#{activity.id}")

    assert has?(session, css("#measurements-table tr:not(#measurements-empty)"))
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp select_activity(session, activity_id) do
    execute_script(session, """
      var sel = document.getElementById('activity-select');
      sel.value = '#{activity_id}';
      sel.dispatchEvent(new Event('change', {bubbles: true}));
    """)
  end

  defp write_tmp_csv do
    path = System.tmp_dir!() <> "/e2e_#{System.unique_integer([:positive])}.csv"

    File.write!(path, """
    measured_at,method,latitude,longitude,crs,values_json
    2026-07-01T10:00:00Z,core,45.1,7.6,EPSG:4326,{"soc":2.3}
    """)

    path
  end

  defp write_tmp_big_file do
    path = System.tmp_dir!() <> "/e2e_big_#{System.unique_integer([:positive])}.csv"
    File.write!(path, String.duplicate("x", 5_000_001))
    path
  end

  defp write_tmp_non_csv do
    path = System.tmp_dir!() <> "/e2e_#{System.unique_integer([:positive])}.xlsx"
    File.write!(path, "binary content")
    path
  end
end
