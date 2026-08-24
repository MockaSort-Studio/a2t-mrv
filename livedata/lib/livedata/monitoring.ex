defmodule Livedata.Monitoring do
  @moduledoc """
  Decides which activities owe monitoring data.

  An activity is "due" when its monitoring window is open and it has either
  never been measured or has not been measured recently enough.

  ## Provisional rule

  CRCF-04 puts monitoring frequency in the methodology configuration, not in
  code — the required data fields, frequency and acceptable methods are all
  defined per methodology. That engine is #62. Until it lands, "recently
  enough" is the single flat threshold below, applied to every activity
  regardless of methodology. This module is the seam that #62 replaces: the
  row shape `attention_items/1` returns should survive, only the predicate
  changes. (@req: CRCF-04)
  """

  alias Livedata.Projects

  # Provisional — see moduledoc. Not a regulatory figure.
  @stale_after_days 30

  @doc "The provisional staleness threshold, in days."
  @spec stale_after_days() :: pos_integer()
  def stale_after_days, do: @stale_after_days

  @doc """
  Activities that owe data, most overdue first.

  Each row is a `Projects.list_activities_with_stats/1` row plus:

    * `:days_since_measurement` — `nil` when the activity has never been measured
    * `:reason` — `:never_measured` or `:stale`

  Activities whose monitoring window has not opened yet, or has already closed,
  are excluded: nothing is owed outside the monitoring period. (@req: CRCF-14)
  """
  @spec attention_items(Date.t()) :: [map()]
  def attention_items(today \\ Date.utc_today()) do
    Projects.list_activities_with_stats()
    |> Enum.filter(&monitoring_open?(&1, today))
    |> Enum.flat_map(&flag(&1, today))
    |> Enum.sort_by(&{&1.reason == :never_measured, &1.days_since_measurement || 0}, :desc)
  end

  # A monitoring window that has not started owes nothing yet; one that has
  # closed owes nothing any more. A null end date means the window never closes
  # (PERMANENT_REMOVAL). (@req: CRCF-14)
  defp monitoring_open?(activity, today) do
    started? =
      is_nil(activity.monitoring_period_start) or
        Date.compare(activity.monitoring_period_start, today) != :gt

    ended? =
      not is_nil(activity.monitoring_period_end) and
        Date.compare(activity.monitoring_period_end, today) == :lt

    started? and not ended?
  end

  defp flag(%{last_measured_at: nil} = activity, _today) do
    [Map.merge(activity, %{days_since_measurement: nil, reason: :never_measured})]
  end

  defp flag(activity, today) do
    days = Date.diff(today, DateTime.to_date(activity.last_measured_at))

    if days >= @stale_after_days do
      [Map.merge(activity, %{days_since_measurement: days, reason: :stale})]
    else
      []
    end
  end
end
