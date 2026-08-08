defmodule Livedata.Measurements do
  @moduledoc """
  Ingestion + querying of raw measurements. `create_raw_measurement/1` validates
  the manual-entry form, computes the dedup content hash, and inserts one
  append-only raw measurement. (@req: KR 2.2)
  """
  import Ecto.Query

  alias Livedata.Projects.{Activity, Project}
  alias Livedata.Repo
  alias Livedata.Measurements.{Entry, RawMeasurement}

  @manual_source "MANUAL_ENTRY"

  @doc """
  The most recently measured raw measurements across the whole portfolio, newest
  first, each carrying the activity and project it belongs to (@req: CRCF-22).

  This is what the dashboard's live submissions feed reads. It is deliberately
  the same row shape a PubSub broadcast will carry, so real-time propagation
  (#66, KR 2.3) becomes a `stream_insert/4` rather than a rewrite.
  """
  @spec list_recent(pos_integer()) :: [map()]
  def list_recent(limit \\ 10) do
    from(rm in RawMeasurement,
      join: a in Activity,
      on: a.id == rm.activity_id,
      join: p in Project,
      on: p.id == a.project_id,
      order_by: [desc: rm.measured_at],
      limit: ^limit,
      select: %{
        id: rm.id,
        measured_at: rm.measured_at,
        source_type: rm.source_type,
        values: rm.values,
        is_superseded: rm.is_superseded,
        activity_id: a.id,
        activity_name: a.name,
        project_id: p.id,
        project_name: p.name
      }
    )
    |> Repo.all()
  end

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
  Counts raw measurements recorded on or after `since`, by measurement time.
  """
  @spec count_since(DateTime.t()) :: non_neg_integer()
  def count_since(since) do
    Repo.aggregate(from(rm in RawMeasurement, where: rm.measured_at >= ^since), :count)
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
  # Each structural case is tagged ("m"/"l") so a map and a list can never
  # canonicalize to the same shape (type-injective).
  defp canonical(v) when is_map(v) do
    [
      "m",
      v
      |> Enum.sort_by(fn {k, _} -> to_string(k) end)
      |> Enum.map(fn {k, val} -> [to_string(k), canonical(val)] end)
    ]
  end

  defp canonical(v) when is_list(v), do: ["l", Enum.map(v, &canonical/1)]
  defp canonical(v), do: v
end
