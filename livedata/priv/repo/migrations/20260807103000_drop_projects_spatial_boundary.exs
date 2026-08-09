defmodule Livedata.Repo.Migrations.DropProjectsSpatialBoundary do
  use Ecto.Migration

  # The boundary captured at commissioning belongs to the parcel; the column on
  # projects was a leftover from the first registration cut. Project geometry is
  # derived from its parcels. (@req: CRCF-37)
  def up do
    drop_if_exists index(:projects, [:spatial_boundary])
    execute("ALTER TABLE projects DROP COLUMN IF EXISTS spatial_boundary")
  end

  def down do
    execute(
      "ALTER TABLE projects ADD COLUMN spatial_boundary geometry(MultiPolygon, 4326) NOT NULL"
    )

    create index(:projects, [:spatial_boundary], using: :gist)
  end
end
