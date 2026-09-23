defmodule Livedata.Repo.Migrations.DropIngestionModeFromRawMeasurements do
  use Ecto.Migration

  def change do
    alter table(:raw_measurements) do
      remove :ingestion_mode
    end
  end
end
