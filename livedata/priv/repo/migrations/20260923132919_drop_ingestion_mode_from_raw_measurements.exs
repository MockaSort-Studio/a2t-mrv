defmodule Livedata.Repo.Migrations.DropIngestionModeFromRawMeasurements do
  use Ecto.Migration

  def change do
    alter table(:raw_measurements) do
      remove_if_exists :ingestion_mode, :string
    end
  end
end
