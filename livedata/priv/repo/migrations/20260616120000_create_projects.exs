defmodule Livedata.Repo.Migrations.CreateProjects do
  use Ecto.Migration

  def change do
    execute(
      "CREATE EXTENSION IF NOT EXISTS postgis",
      "DROP EXTENSION IF EXISTS postgis"
    )

    create table(:projects, primary_key: false) do
      # @req: CRCF-19
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :text, null: false
      add :description, :text
      add :status, :text, null: false, default: "DRAFT"
      add :operator_id, :uuid
      # @req: CRCF-20
      add :commissioned_at, :utc_datetime_usec, null: false

      # @req: CRCF-20
      timestamps(type: :utc_datetime_usec)
    end

    # @req: CRCF-37 — geometry(MultiPolygon, 4326) NOT NULL
    execute(
      "ALTER TABLE projects ADD COLUMN spatial_boundary geometry(MultiPolygon, 4326) NOT NULL",
      "ALTER TABLE projects DROP COLUMN spatial_boundary"
    )

    create constraint(:projects, :valid_status,
             check:
               "status IN ('DRAFT', 'COMMISSIONED', 'ACTIVE', 'MONITORING', 'CERTIFIED', 'CLOSED')"
           )
  end
end
