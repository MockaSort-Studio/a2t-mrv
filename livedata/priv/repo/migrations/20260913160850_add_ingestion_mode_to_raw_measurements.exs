defmodule Livedata.Repo.Migrations.AddIngestionModeToRawMeasurements do
  use Ecto.Migration

  # @req: CRCF-04
  # Adds `ingestion_mode` — a system-set column recording how each measurement
  # entered the system. Values: FORM_ENTRY (manual entry form) and CSV_UPLOAD
  # (bulk CSV import). The column is NOT NULL; existing rows are backfilled to
  # FORM_ENTRY because prior to PR #124 only the manual form existed, and both
  # paths subsequently used the same MANUAL_ENTRY source_type with no distinction
  # in the database — FORM_ENTRY is the safer label for ambiguous historical rows.
  #
  # `ingestion_mode` is intentionally excluded from content_hash so that the same
  # measurement submitted by different routes is still detected as a duplicate
  # (@req: CRCF-28). It is a DB column (not a provenance key) so it cannot be
  # spoofed through developer-supplied extra_provenance_json.
  #
  # Backfill uses a column DEFAULT rather than a plain UPDATE to avoid tripping
  # the raw_measurements_immutable trigger (@req: CRCF-25).
  def up do
    # NOT NULL DEFAULT 'FORM_ENTRY' backfills existing rows at DDL time without
    # firing the raw_measurements_immutable trigger (@req: CRCF-25), which would
    # reject a plain UPDATE. The default is then dropped so future inserts must
    # supply the value explicitly.
    alter table(:raw_measurements) do
      add :ingestion_mode, :text, null: false, default: "FORM_ENTRY"
    end

    execute "ALTER TABLE raw_measurements ALTER COLUMN ingestion_mode DROP DEFAULT"
  end

  def down do
    alter table(:raw_measurements) do
      remove :ingestion_mode
    end
  end
end
