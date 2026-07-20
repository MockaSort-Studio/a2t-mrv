defmodule Livedata.Repo.Migrations.CreateRawMeasurements do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE"

    # @req: CRCF-04
    execute "CREATE TYPE source_type AS ENUM ('MANUAL_ENTRY', 'REMOTE_SENSING', 'MODEL_OUTPUT')"

    create table(:raw_measurements, primary_key: false) do
      # @req: CRCF-19
      add :id, :uuid, null: false, default: fragment("gen_random_uuid()")
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
      # No references(:raw_measurements) here: TimescaleDB hypertables do not support
      # self-referential FKs on partitioned tables. Application layer enforces referential
      # integrity; the no_self_supersession CHECK constraint covers what the DB can enforce.
      add :superseded_by, :uuid, null: true
      # @req: CRCF-20
      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    # TimescaleDB: convert to hypertable partitioned on measured_at before adding unique constraints
    execute "SELECT create_hypertable('raw_measurements', 'measured_at')"

    # TimescaleDB requires the partition key in any unique constraint
    execute "ALTER TABLE raw_measurements ADD PRIMARY KEY (id, measured_at)"

    # @req: CRCF-28 — unique content_hash; partition key required in unique index for TimescaleDB
    create unique_index(:raw_measurements, [:content_hash, :measured_at])

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
  end

  def down do
    execute "DROP TRIGGER IF EXISTS raw_measurements_immutable ON raw_measurements"
    execute "DROP FUNCTION IF EXISTS prevent_raw_measurement_mutation()"
    drop table(:raw_measurements)
    execute "DROP TYPE IF EXISTS source_type"
  end
end
