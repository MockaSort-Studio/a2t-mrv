defmodule Livedata.Repo.Migrations.CreateDerivedMeasurements do
  use Ecto.Migration

  def up do
    create table(:derived_measurements, primary_key: false) do
      # @req: CRCF-19
      add :id, :uuid, null: false, primary_key: true, default: fragment("gen_random_uuid()")
      # @req: CRCF-21, CRCF-23
      add :activity_id, references(:activities, type: :uuid, on_delete: :restrict), null: false
      # @req: CRCF-33
      add :computation_id, :uuid, null: false
      add :type, :text, null: false
      # @req: CRCF-07, CRCF-27
      add :values, :map, null: false
      # @req: CRCF-26
      add :is_superseded, :boolean, null: false, default: false
      # @req: CRCF-26
      add :superseded_by, references(:derived_measurements, type: :uuid), null: true
      # @req: CRCF-20
      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    # @req: CRCF-26
    create constraint(:derived_measurements, :superseded_must_have_superseded_by,
             check: "NOT is_superseded OR superseded_by IS NOT NULL"
           )

    # @req: CRCF-26
    create constraint(:derived_measurements, :no_self_supersession,
             check: "superseded_by IS DISTINCT FROM id"
           )

    # @req: CRCF-25 — append-only enforcement via DB trigger
    execute """
    CREATE OR REPLACE FUNCTION prevent_derived_measurement_mutation()
    RETURNS trigger AS $$
    BEGIN
      RAISE EXCEPTION 'derived_measurements is append-only: mutations are forbidden';
    END;
    $$ LANGUAGE plpgsql
    """

    execute """
    CREATE TRIGGER derived_measurements_immutable
    BEFORE UPDATE OR DELETE ON derived_measurements
    FOR EACH ROW EXECUTE FUNCTION prevent_derived_measurement_mutation()
    """
  end

  def down do
    execute "DROP TRIGGER IF EXISTS derived_measurements_immutable ON derived_measurements"
    execute "DROP FUNCTION IF EXISTS prevent_derived_measurement_mutation()"
    drop table(:derived_measurements)
  end
end
