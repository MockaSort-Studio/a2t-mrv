defmodule Livedata.Repo.Migrations.AddMethodologyFkToActivityMethodologies do
  use Ecto.Migration

  # @req: CRCF-35 — methodology_id was a bare uuid; enforce referential integrity.
  def change do
    alter table(:activity_methodologies) do
      modify :methodology_id,
             references(:methodologies, type: :uuid, on_delete: :restrict),
             from: :uuid,
             null: false
    end
  end
end
