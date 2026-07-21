defmodule Livedata.Repo.Migrations.CreateDerivedMeasurementSources do
  use Ecto.Migration

  def up do
    create table(:derived_measurement_sources, primary_key: false) do
      # @req: CRCF-24
      add :derived_id,
          references(:derived_measurements, type: :uuid, on_delete: :restrict),
          null: false

      # @req: CRCF-33
      # No FK to raw_measurements: raw_measurements is a TimescaleDB hypertable with composite
      # PK (id, measured_at). PostgreSQL cannot reference a non-unique column subset of a
      # composite key. Application layer enforces referential integrity.
      add :source_id, :uuid, null: false
    end

    execute "ALTER TABLE derived_measurement_sources ADD PRIMARY KEY (derived_id, source_id)"

    # @req: CRCF-33 — single-consumption: one raw measurement cannot contribute to more than one derived result
    create unique_index(:derived_measurement_sources, [:source_id])
  end

  def down do
    drop table(:derived_measurement_sources)
  end
end
