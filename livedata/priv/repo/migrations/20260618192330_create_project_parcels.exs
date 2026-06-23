defmodule Livedata.Repo.Migrations.CreateProjectParcels do
  use Ecto.Migration

  def change do
    create table(:project_parcels, primary_key: false) do
      # @req: CRCF-19
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      # @req: CRCF-21
      add :project_id, references(:projects, type: :uuid, on_delete: :delete_all), null: false
      add :parcel_ref, :text, null: false
      # @req: CRCF-36
      add :data_source, :text, null: false
      # for future use when we add the steward/community table
      add :operator_id, :uuid
      # @req: CRCF-20
      add :commissioned_at, :utc_datetime_usec, null: false
      # @req: CRCF-20
      timestamps(type: :utc_datetime_usec)
    end

    # @req: CRCF-37 — geometry(MultiPolygon, 4326) NOT NULL
    execute(
      "ALTER TABLE project_parcels ADD COLUMN boundary geometry(MultiPolygon, 4326) NOT NULL",
      "ALTER TABLE project_parcels DROP COLUMN boundary"
    )

    create index(:project_parcels, [:boundary], using: :gist)

    create constraint(:project_parcels, :valid_data_source,
             check: "data_source IN ('LPIS', 'CADASTER')"
           )
  end
end
