defmodule Livedata.Repo.Migrations.DropTimescaledb do
  use Ecto.Migration

  # Removes the TimescaleDB extension and hypertable from raw_measurements,
  # restoring it to a plain Postgres table. Reverses the TimescaleDB portion of
  # 20260720205727_create_raw_measurements.exs. See issue #138 for the decision.
  #
  # Approach: copy data out, drop the hypertable (which removes all chunks), drop
  # the extension, recreate the table cleanly, restore data. The extension DROP
  # happens after the table DROP so CASCADE does not touch our data copy.
  def up do
    execute "CREATE TABLE raw_measurements_bak AS
      SELECT id, activity_id, measured_at, source_type, content_hash,
             provenance, values, is_superseded, superseded_by, inserted_at
      FROM raw_measurements"

    # Dropping the hypertable removes the parent table and all TimescaleDB chunks.
    execute "DROP TRIGGER IF EXISTS raw_measurements_immutable ON raw_measurements"
    execute "DROP FUNCTION IF EXISTS prevent_raw_measurement_mutation()"
    execute "DROP TABLE raw_measurements"
    execute "DROP EXTENSION IF EXISTS timescaledb CASCADE"

    # Recreate as a plain Postgres table with a simple primary key.
    # superseded_by FK is added after data restore to avoid ordering constraints.
    create table(:raw_measurements, primary_key: false) do
      # @req: CRCF-19
      add :id, :uuid, null: false, primary_key: true, default: fragment("gen_random_uuid()")
      # @req: CRCF-21
      add :activity_id, references(:activities, type: :uuid, on_delete: :restrict), null: false
      # @req: CRCF-20
      add :measured_at, :utc_datetime_usec, null: false
      # @req: CRCF-04
      add :source_type, :source_type, null: false
      # @req: CRCF-28
      add :content_hash, :text, null: false
      # @req: CRCF-04, CRCF-07
      add :provenance, :map, null: false
      # @req: CRCF-27
      add :values, :map, null: false
      # @req: CRCF-26
      add :is_superseded, :boolean, null: false, default: false
      # @req: CRCF-26
      add :superseded_by, :uuid, null: true
      # @req: CRCF-20
      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    execute "INSERT INTO raw_measurements
               (id, activity_id, measured_at, source_type, content_hash,
                provenance, values, is_superseded, superseded_by, inserted_at)
             SELECT id, activity_id, measured_at, source_type, content_hash,
                    provenance, values, is_superseded, superseded_by, inserted_at
             FROM raw_measurements_bak"

    execute "DROP TABLE raw_measurements_bak"

    # @req: CRCF-28 — unique content_hash without the TimescaleDB partition-key requirement
    create unique_index(:raw_measurements, [:content_hash])

    # BRIN index on measured_at — cheaper than B-tree for this append-only,
    # naturally time-ordered table. Covers staleness-monitoring range scans and
    # ORDER BY measured_at DESC queries at the cost of less precise block pruning.
    execute "CREATE INDEX raw_measurements_measured_at_idx
             ON raw_measurements USING BRIN (measured_at)"

    # @req: CRCF-26 — self-referential FK, now possible without the hypertable
    execute "ALTER TABLE raw_measurements
               ADD CONSTRAINT raw_measurements_superseded_by_fkey
               FOREIGN KEY (superseded_by) REFERENCES raw_measurements(id)"

    # @req: CRCF-26
    create constraint(:raw_measurements, :superseded_must_have_superseded_by,
             check: "NOT is_superseded OR superseded_by IS NOT NULL"
           )

    # @req: CRCF-26
    create constraint(:raw_measurements, :no_self_supersession,
             check: "superseded_by IS DISTINCT FROM id"
           )

    # @req: CRCF-25 — append-only enforcement via DB trigger
    execute """
    CREATE OR REPLACE FUNCTION prevent_raw_measurement_mutation()
    RETURNS trigger AS $$
    BEGIN
      RAISE EXCEPTION 'raw_measurements is append-only: mutations are forbidden';
    END;
    $$ LANGUAGE plpgsql
    """

    execute """
    CREATE TRIGGER raw_measurements_immutable
    BEFORE UPDATE OR DELETE ON raw_measurements
    FOR EACH ROW EXECUTE FUNCTION prevent_raw_measurement_mutation()
    """

    # @req: CRCF-33 — FK from derived_measurement_sources to raw_measurements;
    # previously blocked by the hypertable composite PK
    execute "ALTER TABLE derived_measurement_sources
               ADD CONSTRAINT derived_measurement_sources_source_id_fkey
               FOREIGN KEY (source_id) REFERENCES raw_measurements(id) ON DELETE RESTRICT"
  end

  def down do
    execute "ALTER TABLE derived_measurement_sources
               DROP CONSTRAINT IF EXISTS derived_measurement_sources_source_id_fkey"
    execute "DROP TRIGGER IF EXISTS raw_measurements_immutable ON raw_measurements"
    execute "DROP FUNCTION IF EXISTS prevent_raw_measurement_mutation()"
    execute "ALTER TABLE raw_measurements
               DROP CONSTRAINT IF EXISTS raw_measurements_superseded_by_fkey"
    drop_if_exists constraint(:raw_measurements, :superseded_must_have_superseded_by)
    drop_if_exists constraint(:raw_measurements, :no_self_supersession)
    drop_if_exists index(:raw_measurements, [:content_hash])
    execute "DROP INDEX IF EXISTS raw_measurements_measured_at_idx"
    drop table(:raw_measurements)
    # Restoring the TimescaleDB hypertable is not supported in this down migration.
    # Re-run migrations from scratch (mix ecto.reset) to rebuild the pre-change schema.
  end
end
