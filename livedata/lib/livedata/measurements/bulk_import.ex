defmodule Livedata.Measurements.BulkImport do
  @moduledoc """
  All-or-nothing bulk import of raw measurements from a parsed CSV.

  Validates every row through the Entry changeset, detects batch-internal
  duplicates by content_hash, then inserts all rows in a single Ecto.Multi
  transaction. A single invalid row or duplicate causes the whole batch to
  be rejected — no partial import. (@req: CRCF-27, CRCF-28, CRCF-38)
  """

  alias Ecto.Multi
  alias Livedata.Measurements
  alias Livedata.Measurements.{CsvParser, Entry, RawMeasurement}
  alias Livedata.Repo

  @manual_source "MANUAL_ENTRY"

  @type row_error :: %{row: pos_integer(), field: atom(), message: String.t()}

  @spec import_csv(binary(), String.t()) ::
          {:ok, [%RawMeasurement{}]}
          | {:error, [row_error()] | :invalid_header | :no_data_rows | :empty_file}
  def import_csv(activity_id, csv_text) do
    with {:ok, rows} <- CsvParser.parse(csv_text),
         {:ok, validated} <- validate_rows(rows, activity_id),
         :ok <- check_batch_duplicates(validated) do
      insert_all(validated)
    end
  end

  # ---------------------------------------------------------------------------
  # Row validation
  # ---------------------------------------------------------------------------

  defp validate_rows(rows, activity_id) do
    {changesets, errors} =
      rows
      |> Enum.map(&validate_row(&1, activity_id))
      |> Enum.split_with(fn {status, _} -> status == :ok end)

    if errors == [] do
      {:ok, Enum.map(changesets, fn {:ok, cs} -> cs end)}
    else
      {:error, Enum.flat_map(errors, fn {:error, errs} -> errs end)}
    end
  end

  defp validate_row(row, activity_id) do
    row_num = Map.get(row, "_row", 0)
    params = Map.merge(row, %{"activity_id" => activity_id})
    changeset = Entry.changeset(%Entry{}, params) |> Map.put(:action, :validate)

    if changeset.valid? do
      entry = Ecto.Changeset.apply_changes(changeset)
      values = Entry.values(entry)
      hash = Measurements.content_hash(@manual_source, activity_id, entry.measured_at, values)

      attrs = %{
        activity_id: activity_id,
        measured_at: entry.measured_at,
        source_type: @manual_source,
        content_hash: hash,
        provenance: Entry.provenance(entry),
        values: values,
        _row: row_num
      }

      {:ok, attrs}
    else
      errors =
        changeset.errors
        |> Enum.map(fn {field, {msg, _opts}} ->
          %{row: row_num, field: field, message: msg}
        end)

      {:error, errors}
    end
  end

  # ---------------------------------------------------------------------------
  # Batch-internal deduplication
  # ---------------------------------------------------------------------------

  defp check_batch_duplicates(validated) do
    hashes = Enum.map(validated, & &1.content_hash)
    unique_hashes = Enum.uniq(hashes)

    if length(hashes) == length(unique_hashes) do
      :ok
    else
      dup_hashes = hashes -- unique_hashes

      errors =
        validated
        |> Enum.filter(&(&1.content_hash in dup_hashes))
        |> Enum.map(&%{row: &1._row, field: :content_hash, message: "duplicate row in this file"})

      {:error, errors}
    end
  end

  # ---------------------------------------------------------------------------
  # Transaction insert
  # ---------------------------------------------------------------------------

  defp insert_all(validated) do
    multi =
      validated
      |> Enum.with_index()
      |> Enum.reduce(Multi.new(), fn {attrs, idx}, multi ->
        Multi.run(multi, {:row, idx}, fn _repo, _changes ->
          insert_one(attrs)
        end)
      end)

    case Repo.transaction(multi) do
      {:ok, results} ->
        rows =
          results |> Enum.sort_by(fn {{:row, i}, _} -> i end) |> Enum.map(fn {_, rm} -> rm end)

        broadcast_all(rows)
        {:ok, rows}

      {:error, {:row, idx}, reason, _changes} ->
        row_num = Enum.at(validated, idx)._row
        {:error, [%{row: row_num, field: :content_hash, message: reason}]}
    end
  end

  defp insert_one(attrs) do
    changeset =
      RawMeasurement.changeset(%RawMeasurement{}, attrs.activity_id, %{
        measured_at: attrs.measured_at,
        source_type: attrs.source_type,
        content_hash: attrs.content_hash,
        provenance: attrs.provenance,
        values: attrs.values
      })

    Repo.insert(changeset)
  rescue
    e in Ecto.ConstraintError ->
      if e.constraint =~ "content_hash",
        do: {:error, "this measurement already exists in the database"},
        else: reraise(e, __STACKTRACE__)
  end

  defp broadcast_all(rows) do
    Enum.each(rows, fn rm ->
      Phoenix.PubSub.broadcast(Livedata.PubSub, "measurements:new", {:measurement_created, rm})
    end)
  end
end
