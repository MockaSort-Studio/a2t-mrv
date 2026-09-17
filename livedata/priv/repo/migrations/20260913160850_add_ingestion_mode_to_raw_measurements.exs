defmodule Livedata.Repo.Migrations.AddIngestionModeToRawMeasurements do
  use Ecto.Migration

  # @req: CRCF-04, CRCF-22
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
  def up do
    alter table(:raw_measurements) do
      add :ingestion_mode, :text, null: true
    end

    execute "UPDATE raw_measurements SET ingestion_mode = 'FORM_ENTRY'"

    execute "ALTER TABLE raw_measurements ALTER COLUMN ingestion_mode SET NOT NULL"
  end

  def down do
    alter table(:raw_measurements) do
      remove :ingestion_mode
    end
  end
end
