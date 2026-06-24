defmodule Livedata.Repo.Migrations.CreateActivityMethodologies do
  use Ecto.Migration

  def change do
    create table(:activity_methodologies, primary_key: false) do
      # @req: CRCF-35
      add :activity_id, references(:activities, type: :uuid, on_delete: :delete_all),
        null: false,
        primary_key: true

      # @req: CRCF-35
      add :methodology_id, :uuid, null: false, primary_key: true

      # @req: CRCF-20
      add :applied_at, :utc_datetime_usec, null: false
    end
  end
end
