defmodule Livedata.Measurements do
  @moduledoc """
  Ingestion + querying of raw measurements. `create_raw_measurement/1` validates
  the manual-entry form, computes the dedup content hash, and inserts one
  append-only raw measurement. (@req: KR 2.2)
  """
  alias Livedata.Repo
  alias Livedata.Measurements.{Entry, RawMeasurement}

  @manual_source "MANUAL_ENTRY"

  @spec create_raw_measurement(map()) ::
          {:ok, %RawMeasurement{}} | {:error, Ecto.Changeset.t()} | {:error, :duplicate}
  def create_raw_measurement(attrs) do
    entry_changeset = Entry.changeset(%Entry{}, attrs)

    if entry_changeset.valid? do
      entry = Ecto.Changeset.apply_changes(entry_changeset)
      provenance = Jason.decode!(entry.provenance_json)
      values = Jason.decode!(entry.values_json)
      hash = content_hash(@manual_source, entry.activity_id, entry.measured_at, values)

      changeset =
        RawMeasurement.changeset(%RawMeasurement{}, entry.activity_id, %{
          measured_at: entry.measured_at,
          source_type: @manual_source,
          content_hash: hash,
          provenance: provenance,
          values: values
        })

      insert_dedup(changeset)
    else
      {:error, Map.put(entry_changeset, :action, :validate)}
    end
  end

  # The content_hash unique index does not translate to a changeset error under
  # TimescaleDB (per-chunk index names differ), so a duplicate raises
  # Ecto.ConstraintError. Rescue only that constraint. (@req: CRCF-28)
  defp insert_dedup(changeset) do
    case Repo.insert(changeset) do
      {:ok, rm} -> {:ok, rm}
      {:error, cs} -> {:error, cs}
    end
  rescue
    e in Ecto.ConstraintError ->
      if e.constraint =~ "content_hash",
        do: {:error, :duplicate},
        else: reraise(e, __STACKTRACE__)
  end

  @doc """
  SHA-256 over a canonical serialization of the measurement content. Excludes
  provenance by design. Key order in `values` does not affect the hash. (@req: CRCF-28)
  """
  @spec content_hash(String.t(), binary(), DateTime.t(), map()) :: String.t()
  def content_hash(source_type, activity_id, measured_at, values) do
    payload =
      Jason.encode!([
        source_type,
        activity_id,
        DateTime.to_iso8601(measured_at),
        canonical(values)
      ])

    :crypto.hash(:sha256, payload) |> Base.encode16(case: :lower)
  end

  # Recursively sorts map keys so semantically-equal payloads hash identically.
  defp canonical(v) when is_map(v) do
    v
    |> Enum.sort_by(fn {k, _} -> to_string(k) end)
    |> Enum.map(fn {k, val} -> [to_string(k), canonical(val)] end)
  end

  defp canonical(v) when is_list(v), do: Enum.map(v, &canonical/1)
  defp canonical(v), do: v
end
