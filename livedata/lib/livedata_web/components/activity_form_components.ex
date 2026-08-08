defmodule LivedataWeb.ActivityFormComponents do
  @moduledoc """
  The activity section of a form, shared by project registration and
  "add activity" so the two can't drift apart.

  Two behaviours are encoded here rather than left to the developer:
  `storage_duration_tier` is shown as a derived, read-only hint because it is
  never user input (@req: CRCF-14), and the end-date inputs disappear for
  `PERMANENT_REMOVAL`, whose storage has no end.

  Expects the form to carry the fields `activity_name`, `activity_description`,
  `activity_type`, `activity_period_start`, `activity_period_end`,
  `monitoring_period_start`, `monitoring_period_end` and `methodology_ids`.
  """
  use Phoenix.Component

  import LivedataWeb.CoreComponents

  alias Livedata.Projects.Activity
  alias LivedataWeb.Format

  @type_options Enum.map(
                  ~w(PERMANENT_REMOVAL FARMING_SEQUESTRATION PRODUCT_STORAGE SOIL_EMISSION_REDUCTION),
                  &{LivedataWeb.Format.activity_type(&1), &1}
                )

  attr :form, Phoenix.HTML.Form, required: true
  attr :methodology_options, :list, required: true
  attr :selected_type, :string, default: nil

  def activity_fields(assigns) do
    assigns =
      assigns
      |> assign(:type_options, @type_options)
      |> assign(:permanent?, assigns.selected_type == "PERMANENT_REMOVAL")
      |> assign(:tier, Activity.tier_for_type(assigns.selected_type))

    ~H"""
    <div id="activity-fields" class="space-y-3">
      <.input field={@form[:activity_name]} type="text" label="Activity name" />
      <.input field={@form[:activity_description]} type="textarea" label="Description" />
      <.input
        field={@form[:activity_type]}
        type="select"
        label="Activity type"
        prompt="Choose a type"
        options={@type_options}
      />

      <p :if={@tier} id="derived-tier" class="text-sm text-base-content/60">
        Storage duration tier: <span class="font-medium text-base-content">{@tier}</span>
        — derived from the activity type.
      </p>

      <.input field={@form[:activity_period_start]} type="date" label="Activity period start" />
      <.input
        :if={not @permanent?}
        field={@form[:activity_period_end]}
        type="date"
        label="Activity period end"
      />
      <.input field={@form[:monitoring_period_start]} type="date" label="Monitoring period start" />
      <.input
        :if={not @permanent?}
        field={@form[:monitoring_period_end]}
        type="date"
        label="Monitoring period end"
      />

      <p :if={@permanent?} id="permanent-note" class="text-sm text-base-content/60">
        {Format.activity_type("PERMANENT_REMOVAL")} has no end date — the activity
        and monitoring periods stay open.
      </p>

      <.input
        field={@form[:methodology_ids]}
        type="select"
        multiple
        label="Methodologies (select one or more)"
        options={@methodology_options}
      />
      <%!--
      A multi-select with nothing selected submits no parameter at all, so
      `used_input?/1` reports the field as untouched and `<.input>` swallows its
      error. Selecting no methodology is exactly the mistake worth reporting,
      so the error is rendered here instead. (@req: CRCF-35, CRCF-38)
      --%>
      <p
        :for={message <- methodology_errors(@form)}
        id="methodology-error"
        class="mt-1.5 flex gap-2 items-center text-sm text-error"
      >
        <.icon name="hero-exclamation-circle" class="size-5" />
        {message}
      </p>
    </div>
    """
  end

  defp methodology_errors(form) do
    if form.action do
      Enum.map(form[:methodology_ids].errors, &translate_error/1)
    else
      []
    end
  end
end
