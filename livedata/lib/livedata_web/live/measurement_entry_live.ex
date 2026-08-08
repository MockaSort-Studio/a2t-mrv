defmodule LivedataWeb.MeasurementEntryLive do
  # @req: KR 2.2
  use LivedataWeb, :live_view

  alias Livedata.Measurements
  alias Livedata.Measurements.Entry
  alias Livedata.Projects

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "New measurement")
     |> assign(:activity_options, activity_options())
     |> assign_form(Entry.changeset(%Entry{}, %{}))}
  end

  # An `activity_id` in the query string pre-selects the activity, so the
  # dashboard's "needs attention" list can hand the developer a form that is
  # already pointed at the right activity. (@req: KR 2.2)
  @impl true
  def handle_params(%{"activity_id" => activity_id}, _uri, socket) do
    {:noreply, assign_form(socket, Entry.changeset(%Entry{}, %{"activity_id" => activity_id}))}
  end

  def handle_params(_params, _uri, socket), do: {:noreply, socket}

  @impl true
  def handle_event("validate", %{"measurement" => params}, socket) do
    changeset = %Entry{} |> Entry.changeset(params) |> Map.put(:action, :validate)
    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"measurement" => params}, socket) do
    case Measurements.create_raw_measurement(params) do
      {:ok, _rm} ->
        {:noreply,
         socket
         |> put_flash(:info, "Measurement recorded.")
         |> assign_form(Entry.changeset(%Entry{}, %{}))}

      {:error, :duplicate} ->
        changeset =
          %Entry{}
          |> Entry.changeset(params)
          |> Map.put(:action, :validate)
          |> Ecto.Changeset.add_error(:values_json, "this measurement has already been submitted")

        {:noreply, assign_form(socket, changeset)}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp activity_options do
    Enum.map(Projects.list_activities(), fn a -> {"#{a.project_name} — #{a.name}", a.id} end)
  end

  defp assign_form(socket, changeset),
    do: assign(socket, :form, to_form(changeset, as: :measurement))

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h1 id="measurement-entry-title" class="text-2xl font-semibold mb-6">Record a measurement</h1>

      <.form
        for={@form}
        id="measurement-entry-form"
        phx-change="validate"
        phx-submit="save"
        class="space-y-4"
      >
        <.input
          field={@form[:activity_id]}
          type="select"
          label="Activity"
          prompt="Choose an activity"
          options={@activity_options}
        />
        <.input field={@form[:measured_at]} type="datetime-local" label="Measured at (UTC)" />
        <.input
          field={@form[:provenance_json]}
          type="textarea"
          label="Provenance (JSON — must include method, latitude, longitude, crs)"
        />
        <.input
          field={@form[:values_json]}
          type="textarea"
          label="Values (JSON object)"
        />
        <button
          type="submit"
          phx-disable-with="Saving…"
          class="rounded-md bg-zinc-900 px-4 py-2 text-sm font-semibold text-white hover:bg-zinc-700"
        >
          Record measurement
        </button>
      </.form>
    </Layouts.app>
    """
  end
end
