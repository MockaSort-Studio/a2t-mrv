defmodule Livedata.Projects.ActivityPeriods do
  @moduledoc """
  The CRCF period rules for an activity, in one place (@req: CRCF-14):

    * monitoring must start on or before the activity starts
    * `PERMANENT_REMOVAL` has no end dates — the storage is indefinite
    * every other type must declare both ends, and monitoring must not end
      before the activity does

  Applied by `Livedata.Projects.Activity` at the schema level and mirrored by
  the form schemas so a developer gets the same rule as live, field-level
  feedback (@req: CRCF-38). All three use the same field names, so this
  operates on any changeset carrying them.
  """
  import Ecto.Changeset

  @permanent "PERMANENT_REMOVAL"

  @spec validate(Ecto.Changeset.t(), [String.t()]) :: Ecto.Changeset.t()
  def validate(changeset, non_permanent_types) do
    type = get_field(changeset, :activity_type)
    a_start = get_field(changeset, :activity_period_start)
    a_end = get_field(changeset, :activity_period_end)
    m_start = get_field(changeset, :monitoring_period_start)
    m_end = get_field(changeset, :monitoring_period_end)

    changeset
    |> validate_start_order(a_start, m_start)
    |> validate_end_dates(type, a_end, m_end, non_permanent_types)
  end

  defp validate_start_order(changeset, a_start, m_start) do
    if a_start && m_start && Date.compare(m_start, a_start) == :gt do
      add_error(changeset, :monitoring_period_start, "must be on or before the activity start")
    else
      changeset
    end
  end

  # Piped sequentially so both end-date fields can be flagged in a single pass.
  defp validate_end_dates(changeset, @permanent, a_end, m_end, _types) do
    changeset
    |> reject_present(:activity_period_end, a_end)
    |> reject_present(:monitoring_period_end, m_end)
  end

  defp validate_end_dates(changeset, type, a_end, m_end, non_permanent_types) do
    changeset =
      if type in non_permanent_types do
        changeset
        |> require_present(:activity_period_end, a_end)
        |> require_present(:monitoring_period_end, m_end)
      else
        changeset
      end

    if a_end && m_end && Date.compare(m_end, a_end) == :lt do
      add_error(changeset, :monitoring_period_end, "must be on or after the activity end")
    else
      changeset
    end
  end

  defp reject_present(cs, _field, nil), do: cs

  defp reject_present(cs, field, _value),
    do: add_error(cs, field, "must be blank for permanent removal")

  defp require_present(cs, field, nil), do: add_error(cs, field, "can't be blank")
  defp require_present(cs, _field, _value), do: cs
end
