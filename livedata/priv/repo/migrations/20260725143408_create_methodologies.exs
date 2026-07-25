defmodule Livedata.Repo.Migrations.CreateMethodologies do
  use Ecto.Migration

  def change do
    create table(:methodologies, primary_key: false) do
      # @req: CRCF-19
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      add :name, :text, null: false
      add :reference, :text
      # @req: CRCF-20
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:methodologies, [:name])
  end
end
