defmodule LivedataWeb.Format do
  @moduledoc """
  Display helpers shared by the developer-facing LiveViews.

  Timestamps are stored in UTC (@req: CRCF-20). Absolute times are rendered
  with an explicit `UTC` suffix rather than silently in server time, so a
  reading's time is never ambiguous. Rendering in the *viewer's* local zone
  needs the browser timezone, which the app does not capture yet — until then
  the dashboard leans on relative times, which are zone-independent.
  """

  @doc """
  A short, zone-independent description of how long ago something happened.

      iex> LivedataWeb.Format.relative_time(nil)
      "never"
  """
  @spec relative_time(DateTime.t() | nil, DateTime.t()) :: String.t()
  def relative_time(datetime, now \\ DateTime.utc_now())

  def relative_time(nil, _now), do: "never"

  def relative_time(datetime, now) do
    seconds = DateTime.diff(now, datetime)

    cond do
      seconds < 0 -> "in the future"
      seconds < 60 -> "just now"
      seconds < 3600 -> "#{div(seconds, 60)} min ago"
      seconds < 86_400 -> "#{div(seconds, 3600)} h ago"
      seconds < 172_800 -> "yesterday"
      true -> "#{div(seconds, 86_400)} days ago"
    end
  end

  @doc "An unambiguous absolute timestamp. (@req: CRCF-20)"
  @spec utc(DateTime.t() | nil) :: String.t()
  def utc(nil), do: "—"

  def utc(datetime) do
    datetime
    |> DateTime.truncate(:second)
    |> Calendar.strftime("%Y-%m-%d %H:%M UTC")
  end

  @doc "A date, or an em dash when absent."
  @spec date(Date.t() | nil) :: String.t()
  def date(nil), do: "—"
  def date(date), do: Date.to_iso8601(date)

  @doc """
  A closed or open-ended period, e.g. `2026-01-01 → 2031-01-01` or
  `2026-01-01 → open-ended` for permanent removals. (@req: CRCF-14)
  """
  @spec period(Date.t() | nil, Date.t() | nil) :: String.t()
  def period(nil, nil), do: "—"
  def period(start_date, nil), do: "#{date(start_date)} → open-ended"
  def period(start_date, end_date), do: "#{date(start_date)} → #{date(end_date)}"

  @doc "Human label for an `activity_type` enum value. (@req: CRCF-13)"
  @spec activity_type(String.t() | nil) :: String.t()
  def activity_type("PERMANENT_REMOVAL"), do: "Permanent removal"
  def activity_type("FARMING_SEQUESTRATION"), do: "Farming sequestration"
  def activity_type("PRODUCT_STORAGE"), do: "Product storage"
  def activity_type("SOIL_EMISSION_REDUCTION"), do: "Soil emission reduction"
  def activity_type(other), do: other || "—"

  @doc """
  A compact one-line preview of a measurement `values` payload — the first few
  key/value pairs, in key order so the preview is stable across renders.
  """
  @spec values_summary(map() | nil, pos_integer()) :: String.t()
  def values_summary(values, take \\ 3)
  def values_summary(nil, _take), do: "—"
  def values_summary(values, _take) when map_size(values) == 0, do: "—"

  def values_summary(values, take) do
    pairs = values |> Enum.sort_by(fn {key, _} -> to_string(key) end) |> Enum.take(take)
    rendered = Enum.map_join(pairs, ", ", fn {key, value} -> "#{key}: #{scalar(value)}" end)
    remaining = map_size(values) - length(pairs)

    if remaining > 0, do: "#{rendered} +#{remaining} more", else: rendered
  end

  defp scalar(value) when is_binary(value), do: value
  defp scalar(value) when is_number(value) or is_boolean(value), do: to_string(value)
  defp scalar(nil), do: "null"
  defp scalar(value), do: Jason.encode!(value)
end
