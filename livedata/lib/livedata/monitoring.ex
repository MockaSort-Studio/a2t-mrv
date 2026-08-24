defmodule Livedata.Monitoring do
  @moduledoc """
  Decides which activities owe monitoring data.

  CRCF-04 puts monitoring frequency in methodology config (#62). Until then a
  flat threshold (`@stale_after_days`) stands in for every activity. This module
  is the seam #62 replaces — the row shape should survive, only the predicate
  changes. (@req: CRCF-04)
  """

  alias Livedata.Projects

  # Provisional — see moduledoc. Not a regulatory figure.
  @stale_after_days 30

  @spec stale_after_days() :: pos_integer()
  def stale_after_days, do: @stale_after_days

  @doc "Activities that owe data, most overdue first. (@req: CRCF-14)"
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
