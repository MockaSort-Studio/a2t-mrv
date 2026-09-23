defmodule LivedataWeb.ActivityShowLive do
  @moduledoc """
  The activity workbench: the regulatory clock on one side, the evidence
  collected against it on the other.

  Measurements are the leaves of the hierarchy (@req: CRCF-21) and this is
  where they are read. Every row can be expanded to its full provenance,
  values and UUID, because that is what an audit asks for
  (@req: CRCF-19, CRCF-22).
  """
  use LivedataWeb, :live_view

  alias Livedata.Measurements
  alias Livedata.Measurements.BulkImport
  alias Livedata.Measurements.Entry
  alias Livedata.Projects
  alias LivedataWeb.Format

  @page_size 25
  @max_file_size 5_000_000
  @source_types ~w(MANUAL_ENTRY REMOTE_SENSING MODEL_OUTPUT)

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    activity = Projects.get_activity_with_context!(id)

    {:ok,
     socket
     |> assign(:page_title, activity.name)
     |> assign(:activity, activity)
     |> assign(:source_types, @source_types)
     |> assign(:filters, %{
       "source_type" => "",
       "from" => "",
       "to" => "",
       "include_superseded" => "true"
     })
     |> assign(:selected_measurement, nil)
     |> assign(:coverage, Measurements.coverage_for_activity(activity.id))
     |> load_measurements(reset: true)
     |> reset_measurement_form()
     |> assign(:show_upload_modal, false)
     |> assign(:upload_errors, [])
     |> assign(:upload_result, nil)
     |> allow_upload(:csv_file,
       accept: ~w(.csv text/csv),
       max_entries: 1,
       max_file_size: @max_file_size
     )}
  end

  @impl true
  def handle_event("toggle_measurement_form", _params, socket) do
    open? = !socket.assigns.measurement_form_open

    {:noreply,
     socket
     |> assign(:measurement_form_open, open?)
     |> then(fn s ->
       if open?,
         do:
           assign_measurement_form(
             s,
             Entry.changeset(%Entry{}, measurement_defaults(socket.assigns.activity.id))
           ),
         else: s
     end)}
  end

  def handle_event("validate_measurement", %{"measurement" => params}, socket) do
    params = build_values_json(params, socket.assigns.measurement_value_pairs)
    changeset = %Entry{} |> Entry.changeset(params) |> Map.put(:action, :validate)

    {:noreply,
     socket
     |> assign(
       :measurement_value_pairs,
       parse_value_rows(params, socket.assigns.measurement_value_pairs)
     )
     |> assign_measurement_form(changeset)}
  end

  def handle_event("create_measurement", %{"measurement" => params}, socket) do
    params = build_values_json(params, socket.assigns.measurement_value_pairs)

    case Measurements.create_raw_measurement(params) do
      {:ok, _measurement} ->
        {:noreply,
         socket
         |> reset_measurement_form()
         |> assign(:coverage, Measurements.coverage_for_activity(socket.assigns.activity.id))
         |> load_measurements(reset: true)
         |> put_flash(:info, "Measurement recorded.")}

      {:error, :duplicate} ->
        changeset =
          %Entry{}
          |> Entry.changeset(params)
          |> Map.put(:action, :validate)
          |> Ecto.Changeset.add_error(
            :values_json,
            "identical reading already exists for this activity at this time"
          )

        {:noreply, assign_measurement_form(socket, changeset)}

      {:error, changeset} ->
        {:noreply, assign_measurement_form(socket, changeset)}
    end
  end

  def handle_event("add_measurement_value", _params, socket) do
    {:noreply,
     assign(
       socket,
       :measurement_value_pairs,
       socket.assigns.measurement_value_pairs ++ [%{"key" => "", "value" => ""}]
     )}
  end

  def handle_event("remove_measurement_value", %{"index" => index}, socket) do
    index = String.to_integer(index)
    pairs = List.delete_at(socket.assigns.measurement_value_pairs, index)

    {:noreply,
     assign(
       socket,
       :measurement_value_pairs,
       if(pairs == [], do: [%{"key" => "", "value" => ""}], else: pairs)
     )}
  end

  def handle_event("set_coordinates", %{"latitude" => lat, "longitude" => lon}, socket) do
    params =
      socket.assigns.measurement_form.params
      |> Map.put("latitude", to_string(lat))
      |> Map.put("longitude", to_string(lon))

    {:noreply, assign_measurement_form(socket, Entry.changeset(%Entry{}, params))}
  end

  def handle_event("toggle_upload_modal", _params, socket) do
    {:noreply,
     socket
     |> assign(:show_upload_modal, !socket.assigns.show_upload_modal)
     |> assign(:upload_errors, [])
     |> assign(:upload_result, nil)}
  end

  def handle_event("validate_upload", _params, socket), do: {:noreply, socket}

  def handle_event("submit_upload", _params, socket) do
    entries = socket.assigns.uploads.csv_file.entries

    cond do
      entries == [] ->
        {:noreply,
         assign(socket, :upload_errors, [
           %{row: nil, field: :file, message: "choose a CSV file to import"}
         ])}

      Enum.any?(entries, fn e -> upload_errors(socket.assigns.uploads.csv_file, e) != [] end) ->
        {:noreply,
         assign(socket, :upload_errors, [
           %{row: nil, field: :file, message: "that file was rejected — choose another"}
         ])}

      Enum.any?(entries, &(not &1.done?)) ->
        {:noreply,
         assign(socket, :upload_errors, [
           %{row: nil, field: :file, message: "file still uploading — try again"}
         ])}

      true ->
        csv_text =
          consume_uploaded_entries(socket, :csv_file, fn %{path: path}, _entry ->
            {:ok, File.read!(path)}
          end)
          |> List.first("")

        case BulkImport.import_csv(socket.assigns.activity.id, csv_text) do
          {:ok, rows} ->
            n = length(rows)
            label = "#{n} measurement#{if n == 1, do: "", else: "s"}"

            {:noreply,
             socket
             |> assign(:show_upload_modal, false)
             |> assign(:upload_errors, [])
             |> assign(:upload_result, nil)
             |> assign(:coverage, Measurements.coverage_for_activity(socket.assigns.activity.id))
             |> load_measurements(reset: true)
             |> put_flash(:info, "#{label} imported.")}

          {:error, errors} when is_list(errors) ->
            {:noreply, socket |> assign(:upload_errors, errors) |> assign(:upload_result, nil)}

          {:error, reason} ->
            {:noreply,
             assign(socket, :upload_errors, [
               %{row: nil, field: :file, message: import_error_message(reason)}
             ])}
        end
    end
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = %{
      "source_type" => params["source_type"] || "",
      "from" => params["from"] || "",
      "to" => params["to"] || "",
      "include_superseded" => params["include_superseded"] || "false"
    }

    {:noreply,
     socket
     |> assign(:filters, filters)
     |> assign(:selected_measurement, nil)
     |> load_measurements(reset: true)}
  end

  def handle_event("load_more", _params, socket) do
    {:noreply, load_measurements(socket, reset: false)}
  end

  def handle_event("select_measurement", %{"id" => id}, socket) do
    measurement = Enum.find(socket.assigns.loaded, &(&1.id == id))
    {:noreply, assign(socket, :selected_measurement, measurement)}
  end

  def handle_event("close_measurement_detail", _params, socket) do
    {:noreply, assign(socket, :selected_measurement, nil)}
  end

  defp reset_measurement_form(socket) do
    socket
    |> assign(:measurement_form_open, false)
    |> assign(:measurement_value_pairs, [%{"key" => "", "value" => ""}])
    |> assign_measurement_form(Entry.changeset(%Entry{}, %{}))
  end

  defp assign_measurement_form(socket, changeset) do
    assign(socket, :measurement_form, to_form(changeset, as: :measurement))
  end

  defp measurement_defaults(activity_id) do
    %{
      "activity_id" => activity_id,
      "measured_at" => DateTime.utc_now() |> DateTime.truncate(:second),
      "crs" => Entry.default_crs()
    }
  end

  defp parse_value_rows(params, fallback) do
    rows =
      params
      |> Map.get("values", %{})
      |> Enum.sort_by(fn {idx, _} -> String.to_integer(idx) end)
      |> Enum.map(fn {_, row} -> %{"key" => row["key"] || "", "value" => row["value"] || ""} end)

    if rows == [], do: fallback, else: rows
  end

  defp build_values_json(params, fallback_pairs) do
    pairs = parse_value_rows(params, fallback_pairs)

    values =
      pairs
      |> Enum.reject(fn %{"key" => k} -> String.trim(k) == "" end)
      |> Map.new(fn %{"key" => k, "value" => v} ->
        trimmed = String.trim(v)

        {String.trim(k),
         case Float.parse(trimmed) do
           {n, ""} -> n
           _ -> trimmed
         end}
      end)

    Map.put(params, "values_json", Jason.encode!(values))
  end

  defp load_measurements(socket, reset: reset?) do
    offset = if reset?, do: 0, else: socket.assigns.loaded_count
    opts = Keyword.merge(query_opts(socket.assigns.filters), limit: @page_size, offset: offset)
    page = Measurements.list_for_activity(socket.assigns.activity.id, opts)

    total =
      Measurements.count_for_activity(
        socket.assigns.activity.id,
        query_opts(socket.assigns.filters)
      )

    loaded = if reset?, do: page, else: socket.assigns.loaded ++ page

    socket
    |> assign(:loaded, loaded)
    |> assign(:loaded_count, length(loaded))
    |> assign(:total, total)
    |> stream(:measurements, page, reset: reset?)
  end

  defp query_opts(filters) do
    [
      source_type: filters["source_type"],
      from: parse_date_start(filters["from"]),
      to: parse_date_end(filters["to"]),
      include_superseded: filters["include_superseded"] == "true"
    ]
  end

  defp parse_date_start(blank) when blank in [nil, ""], do: nil

  defp parse_date_start(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
      _ -> nil
    end
  end

  defp parse_date_end(blank) when blank in [nil, ""], do: nil

  defp parse_date_end(date_str) do
    case Date.from_iso8601(date_str) do
      {:ok, date} -> DateTime.new!(date, ~T[23:59:59], "Etc/UTC")
      _ -> nil
    end
  end

  defp upload_error_to_string(:too_large),
    do: "File too large (max #{div(@max_file_size, 1_000_000)} MB)."

  defp upload_error_to_string(:not_accepted), do: "Only CSV files are accepted."
  defp upload_error_to_string(:too_many_files), do: "Upload one file at a time."
  defp upload_error_to_string(_), do: "Upload error."

  defp import_error_message(:empty_file), do: "The file is empty."

  defp import_error_message(:invalid_header),
    do:
      "Missing required columns. Expected: measured_at, method, latitude, longitude, values_json."

  defp import_error_message(:no_data_rows), do: "The file has no data rows."
  defp import_error_message(_), do: "Could not process the file."

  defp values_errors(form) do
    if form.action, do: Enum.map(form[:values_json].errors, &translate_error/1), else: []
  end

  defp provenance_summary(%{provenance: nil}), do: "—"

  defp provenance_summary(%{provenance: provenance}) do
    method = provenance["method"] || "unknown method"
    lat = provenance["latitude"]
    lon = provenance["longitude"]

    if lat && lon, do: "#{method} @ #{lat}, #{lon}", else: method
  end

  defp pretty_json(nil), do: "null"
  defp pretty_json(term), do: Jason.encode!(term, pretty: true)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} max_width="max-w-6xl">
      <%!-- Measurement detail popover --%>
      <.modal
        id="detail-popover"
        show={!!@selected_measurement}
        on_cancel="close_measurement_detail"
        max_width="max-w-md"
      >
        <div class="flex shrink-0 items-center justify-between border-b border-base-300 px-5 py-4">
          <div>
            <p class="font-mono text-xs text-base-content/40">
              {@selected_measurement && @selected_measurement.id}
            </p>
            <p class="mt-0.5 text-sm font-semibold">
              {@selected_measurement && Format.utc(@selected_measurement.measured_at)}
            </p>
          </div>
          <button
            id="close-detail-popover"
            type="button"
            phx-click="close_measurement_detail"
            class="rounded-md p-1 text-base-content/50 transition-colors hover:bg-base-200 hover:text-base-content"
          >
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </div>

        <div class="space-y-4 px-5 py-4">
          <div class="flex items-center gap-2">
            <span class="rounded bg-base-200 px-2 py-0.5 text-xs font-medium text-base-content/60">
              {@selected_measurement && @selected_measurement.source_type}
            </span>
            <span
              id="detail-ingestion-mode"
              class="rounded bg-base-200 px-2 py-0.5 text-xs font-medium text-base-content/60"
            >
              {@selected_measurement && @selected_measurement.ingestion_mode}
            </span>
            <span
              :if={@selected_measurement && @selected_measurement.is_superseded}
              class="rounded bg-amber-100 px-2 py-0.5 text-xs font-medium text-amber-800"
            >
              superseded
            </span>
          </div>

          <div>
            <p class="mb-1.5 text-xs font-medium uppercase tracking-wide text-base-content/50">
              Provenance
            </p>
            <pre
              phx-no-curly-interpolation
              class="overflow-x-auto rounded-lg bg-base-200 p-3 text-xs text-base-content/80"
            ><%= @selected_measurement && pretty_json(@selected_measurement.provenance) %></pre>
          </div>

          <div>
            <p class="mb-1.5 text-xs font-medium uppercase tracking-wide text-base-content/50">
              Values
            </p>
            <pre
              phx-no-curly-interpolation
              class="overflow-x-auto rounded-lg bg-base-200 p-3 text-xs text-base-content/80"
            ><%= @selected_measurement && pretty_json(@selected_measurement.values) %></pre>
          </div>
        </div>
      </.modal>

      <%!-- Upload measurements modal --%>
      <.modal
        id="upload-modal"
        show={@show_upload_modal}
        on_cancel="toggle_upload_modal"
        max_width="max-w-md"
      >
        <div class="flex shrink-0 items-center justify-between border-b border-base-300 px-6 py-4">
          <h2 class="text-lg font-semibold">Upload measurements</h2>
          <button
            id="close-upload-modal"
            type="button"
            phx-click="toggle_upload_modal"
            class="rounded-md p-1 text-base-content/50 transition-colors hover:bg-base-200 hover:text-base-content"
          >
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </div>

        <.form
          for={%{}}
          id="upload-modal-form"
          phx-change="validate_upload"
          phx-submit="submit_upload"
        >
          <div class="space-y-4 px-6 py-5">
            <p class="text-sm text-base-content/60">
              Required columns:
              <code phx-no-curly-interpolation class="text-xs">
                measured_at, method, latitude, longitude, crs, values_json
              </code>
            </p>

            <div class="relative rounded-lg border-2 border-dashed border-base-300 px-5 py-7 text-center transition-colors hover:border-base-content/30 hover:bg-base-200/30">
              <.live_file_input
                upload={@uploads.csv_file}
                class="absolute inset-0 h-full w-full cursor-pointer opacity-0"
              />
              <%= if @uploads.csv_file.entries == [] do %>
                <div class="pointer-events-none space-y-1">
                  <.icon name="hero-arrow-up-tray" class="mx-auto size-7 text-base-content/30" />
                  <p class="text-sm font-medium text-base-content/60">Click or drag to upload</p>
                  <p class="text-xs text-base-content/40">CSV only · max 5 MB</p>
                </div>
              <% else %>
                <div class="pointer-events-none space-y-1">
                  <.icon name="hero-document-text" class="mx-auto size-7 text-primary/60" />
                  <p class="text-sm font-medium">{hd(@uploads.csv_file.entries).client_name}</p>
                  <p class="text-xs text-base-content/40">
                    {Float.round(hd(@uploads.csv_file.entries).client_size / 1_000, 1)} KB · click to change
                  </p>
                </div>
              <% end %>
            </div>

            <%= for entry <- @uploads.csv_file.entries do %>
              <p :for={err <- upload_errors(@uploads.csv_file, entry)} class="text-sm text-error">
                {upload_error_to_string(err)}
              </p>
            <% end %>

            <div
              :if={@upload_errors != []}
              id="upload-errors"
              class="space-y-1 rounded-lg border border-error/30 bg-error/5 p-3"
            >
              <p class="text-sm font-medium text-error">Import failed</p>
              <ul class="space-y-0.5 text-sm text-error/80">
                <li :for={err <- Enum.take(@upload_errors, 50)}>
                  {if err.row, do: "Row #{err.row}: "}{err.message}
                </li>
              </ul>
              <p :if={length(@upload_errors) > 50} class="text-xs text-error/60">
                …and {length(@upload_errors) - 50} more errors.
              </p>
            </div>
          </div>

          <div class="flex gap-3 border-t border-base-300 px-6 py-4">
            <button
              type="submit"
              phx-disable-with="Importing…"
              class="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-content transition-colors hover:opacity-90"
            >
              Import
            </button>
            <button
              type="button"
              phx-click="toggle_upload_modal"
              class="rounded-md px-4 py-2 text-sm font-semibold text-base-content/50 transition-colors hover:text-base-content"
            >
              Cancel
            </button>
          </div>
        </.form>
      </.modal>

      <%!-- Record measurement modal --%>
      <.modal
        id="measurement-modal"
        show={@measurement_form_open}
        on_cancel="toggle_measurement_form"
        style="height: min(90vh, 780px);"
      >
        <div class="flex shrink-0 items-center justify-between border-b border-base-300 px-6 py-4">
          <h2 class="text-lg font-semibold">Record measurement</h2>
          <button
            id="close-measurement-modal"
            type="button"
            phx-click="toggle_measurement_form"
            class="rounded-md p-1 text-base-content/50 transition-colors hover:bg-base-200 hover:text-base-content"
          >
            <.icon name="hero-x-mark" class="size-5" />
          </button>
        </div>

        <div class="flex-1 overflow-y-auto px-6 py-5">
          <.form
            for={@measurement_form}
            id="measurement-modal-form"
            phx-change="validate_measurement"
            phx-submit="create_measurement"
            class="space-y-4"
          >
            <input type="hidden" name="measurement[activity_id]" value={@activity.id} />

            <.input
              field={@measurement_form[:measured_at]}
              type="datetime-local"
              label="Measured at (UTC)"
            />

            <div class="grid gap-3 sm:grid-cols-3">
              <.input field={@measurement_form[:latitude]} type="number" step="any" label="Latitude" />
              <.input
                field={@measurement_form[:longitude]}
                type="number"
                step="any"
                label="Longitude"
              />
              <.input
                field={@measurement_form[:crs]}
                type="select"
                label="CRS"
                options={Entry.crs_options()}
              />
            </div>

            <.input field={@measurement_form[:method]} type="text" label="Method" />

            <button
              type="button"
              id="use-my-location-modal"
              phx-hook=".GeolocateModal"
              class="rounded-md border border-base-300 px-3 py-1.5 text-sm font-semibold transition-colors hover:bg-base-200"
            >
              Use my current location
            </button>
            <script :type={Phoenix.LiveView.ColocatedHook} name=".GeolocateModal">
              export default {
                mounted() {
                  this.el.addEventListener("click", () => {
                    if (!navigator.geolocation) { return }
                    navigator.geolocation.getCurrentPosition((pos) => {
                      this.pushEvent("set_coordinates", {
                        latitude: pos.coords.latitude,
                        longitude: pos.coords.longitude,
                      })
                    })
                  })
                }
              }
            </script>

            <div id="measurement-values-repeater" class="space-y-2">
              <p class="text-sm font-medium">Values</p>
              <div
                :for={{pair, index} <- Enum.with_index(@measurement_value_pairs)}
                class="flex items-end gap-2"
              >
                <label class="flex-1 text-sm">
                  <span class="mb-1 block text-base-content/60">Name</span>
                  <input
                    type="text"
                    name={"measurement[values][#{index}][key]"}
                    value={pair["key"]}
                    class="w-full input input-sm"
                  />
                </label>
                <label class="flex-1 text-sm">
                  <span class="mb-1 block text-base-content/60">Value</span>
                  <input
                    type="text"
                    name={"measurement[values][#{index}][value]"}
                    value={pair["value"]}
                    class="w-full input input-sm"
                  />
                </label>
                <button
                  type="button"
                  id={"remove-value-#{index}"}
                  phx-click="remove_measurement_value"
                  phx-value-index={index}
                  class="mb-1 rounded-md border border-base-300 px-2 py-1.5 text-sm transition-colors hover:bg-base-200"
                >
                  <.icon name="hero-x-mark-micro" class="size-4" />
                </button>
              </div>
              <button
                type="button"
                id="add-measurement-value"
                phx-click="add_measurement_value"
                class="rounded-md border border-base-300 px-3 py-1 text-sm font-semibold transition-colors hover:bg-base-200"
              >
                + Add value
              </button>
              <.input field={@measurement_form[:values_json]} type="hidden" />
              <p
                :for={msg <- values_errors(@measurement_form)}
                class="mt-1 flex items-center gap-1.5 text-sm text-error"
              >
                <.icon name="hero-exclamation-circle" class="size-4" /> {msg}
              </p>
            </div>
          </.form>
        </div>

        <div class="flex shrink-0 gap-3 border-t border-base-300 px-6 py-4">
          <button
            type="submit"
            form="measurement-modal-form"
            phx-disable-with="Recording…"
            class="rounded-md bg-primary px-4 py-2 text-sm font-semibold text-primary-content transition-colors hover:opacity-90"
          >
            Record
          </button>
          <button
            type="button"
            phx-click="toggle_measurement_form"
            class="rounded-md px-4 py-2 text-sm font-semibold text-base-content/50 transition-colors hover:text-base-content"
          >
            Cancel
          </button>
        </div>
      </.modal>

      <:breadcrumbs>
        <Layouts.crumb navigate={~p"/"}>Projects</Layouts.crumb>
        <Layouts.crumb navigate={~p"/projects/#{@activity.project_id}"}>
          {@activity.project_name}
        </Layouts.crumb>
        <Layouts.crumb>{@activity.name}</Layouts.crumb>
      </:breadcrumbs>

      <div id="activity-detail" class="space-y-6">
        <%!-- @req: CRCF-19 --%>
        <header class="flex flex-wrap items-start justify-between gap-3">
          <div>
            <div class="flex items-center gap-2">
              <h1 class="text-2xl font-semibold">{@activity.name}</h1>
              <span class="rounded-full bg-base-200 px-2 py-0.5 text-xs font-medium text-base-content/70">
                {String.capitalize(@activity.status)}
              </span>
            </div>
            <p class="mt-1 text-sm text-base-content/60">
              {Format.activity_type(@activity.activity_type)}
            </p>
            <p class="mt-0.5 text-sm text-base-content/60">
              Created {Format.utc(@activity.inserted_at)}
            </p>
          </div>
        </header>

        <dl id="activity-coverage" class="grid grid-cols-2 gap-3 sm:grid-cols-3">
          <div class="rounded-lg border border-base-300 px-4 py-3">
            <dt class="text-sm text-base-content/60">Measurements</dt>
            <dd class="mt-1 text-2xl font-semibold">{@coverage.count}</dd>
          </div>
          <div class="rounded-lg border border-base-300 px-4 py-3">
            <dt class="text-sm text-base-content/60">Monitoring period</dt>
            <dd class="mt-1 text-sm">
              {Format.period(@activity.monitoring_period_start, @activity.monitoring_period_end)}
            </dd>
          </div>
          <div class="rounded-lg border border-base-300 px-4 py-3">
            <dt class="text-sm text-base-content/60">Last measured</dt>
            <dd class="mt-1 text-sm">
              {Format.relative_time(@coverage.last_measured_at)}
            </dd>
          </div>
        </dl>

        <section class="space-y-3">
          <div class="flex flex-wrap items-end justify-between gap-3">
            <div class="flex items-center gap-2">
              <h2 class="text-lg font-medium">Measurements</h2>
              <button
                id="open-measurement-form"
                type="button"
                phx-click="toggle_measurement_form"
                title="Record measurement"
                class="flex size-6 items-center justify-center rounded-md border border-base-300 text-base-content/60 transition-colors hover:bg-base-200 hover:text-base-content"
              >
                <.icon name="hero-plus-micro" class="size-4" />
              </button>
              <button
                id="open-upload-modal"
                type="button"
                phx-click="toggle_upload_modal"
                title="Upload CSV"
                class="flex size-6 items-center justify-center rounded-md border border-base-300 text-base-content/60 transition-colors hover:bg-base-200 hover:text-base-content"
              >
                <.icon name="hero-arrow-up-tray-micro" class="size-4" />
              </button>
            </div>

            <form id="measurement-filters" phx-change="filter" class="flex items-end gap-3">
              <label class="text-sm">
                <span class="mb-1 block text-base-content/60">Source</span>
                <select name="source_type" class="select select-sm">
                  <option value="">All sources</option>
                  <option
                    :for={type <- @source_types}
                    value={type}
                    selected={@filters["source_type"] == type}
                  >
                    {type}
                  </option>
                </select>
              </label>
              <label class="text-sm">
                <span class="mb-1 block text-base-content/60">From</span>
                <input
                  type="date"
                  name="from"
                  id="filter-from"
                  value={@filters["from"]}
                  class="rounded-md border border-base-300 px-2 py-1 text-sm"
                />
              </label>
              <label class="text-sm">
                <span class="mb-1 block text-base-content/60">To</span>
                <input
                  type="date"
                  name="to"
                  id="filter-to"
                  value={@filters["to"]}
                  class="rounded-md border border-base-300 px-2 py-1 text-sm"
                />
              </label>
              <label class="flex items-center gap-2 pb-2 text-sm">
                <input type="hidden" name="include_superseded" value="false" />
                <input
                  type="checkbox"
                  name="include_superseded"
                  value="true"
                  checked={@filters["include_superseded"] == "true"}
                  class="checkbox checkbox-sm"
                /> Show superseded
              </label>
            </form>
          </div>

          <div class="overflow-x-auto rounded-lg border border-base-300">
            <table class="w-full text-sm">
              <thead class="text-left text-base-content/60">
                <tr class="border-b border-base-300">
                  <th class="px-4 py-2 font-medium">Measured at</th>
                  <th class="px-4 py-2 font-medium">Source</th>
                  <th class="px-4 py-2 font-medium">Values</th>
                  <th class="px-4 py-2 font-medium">Provenance</th>
                </tr>
              </thead>
              <tbody id="measurements-table" phx-update="stream" class="divide-y divide-base-300">
                <tr id="measurements-empty" class="hidden only:table-row">
                  <td colspan="4" class="px-4 py-6 text-center text-base-content/60">
                    No measurements match these filters.
                  </td>
                </tr>
                <tr
                  :for={{dom_id, m} <- @streams.measurements}
                  id={dom_id}
                  phx-click="select_measurement"
                  phx-value-id={m.id}
                  class="cursor-pointer align-top transition-colors hover:bg-base-200/50"
                >
                  <td class="px-4 py-2 whitespace-nowrap">
                    {Format.utc(m.measured_at)}
                    <span
                      :if={m.is_superseded}
                      class="ml-1 rounded bg-amber-100 px-1.5 py-0.5 text-xs font-medium text-amber-800"
                    >
                      superseded
                    </span>
                  </td>
                  <td class="px-4 py-2">
                    <span class="rounded bg-base-200 px-1.5 py-0.5 text-xs font-medium text-base-content/60">
                      {m.source_type}
                    </span>
                  </td>
                  <td class="px-4 py-2 text-base-content/70">{Format.values_summary(m.values)}</td>
                  <td class="px-4 py-2 text-base-content/70">{provenance_summary(m)}</td>
                </tr>
              </tbody>
            </table>
          </div>

          <div class="flex items-center justify-between text-sm text-base-content/60">
            <span id="measurements-count">
              Showing {@loaded_count} of {@total}
            </span>
            <button
              :if={@loaded_count < @total}
              id="load-more"
              type="button"
              phx-click="load_more"
              class="rounded-md border border-base-300 px-3 py-1.5 font-semibold text-base-content transition-colors hover:bg-base-200"
            >
              Load more
            </button>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end
end
