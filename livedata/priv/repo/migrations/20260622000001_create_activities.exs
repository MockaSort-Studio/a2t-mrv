defmodule Livedata.Repo.Migrations.CreateActivities do
  use Ecto.Migration

  def change do
    create table(:activities, primary_key: false) do
      # @req: CRCF-19
      add :id, :uuid, primary_key: true, default: fragment("gen_random_uuid()")
      # @req: CRCF-34
      add :project_id, references(:projects, type: :uuid, on_delete: :delete_all), null: false
      add :name, :text, null: false
      add :description, :text
      # @req: CRCF-13
      add :activity_type, :text, null: false
      # @req: CRCF-14
      add :storage_duration_tier, :text, null: false
      add :status, :text, null: false, default: "REGISTERED"
      add :activity_period_start, :date, null: false
      add :activity_period_end, :date
      add :monitoring_period_start, :date, null: false
      add :monitoring_period_end, :date
      # @req: CRCF-20
      timestamps(type: :utc_datetime_usec)
    end

    # @req: CRCF-13
    create constraint(:activities, :valid_activity_type,
             check:
               "activity_type IN ('PERMANENT_REMOVAL', 'FARMING_SEQUESTRATION', 'PRODUCT_STORAGE', 'SOIL_EMISSION_REDUCTION')"
           )

    # @req: CRCF-14
    create constraint(:activities, :valid_storage_duration_tier,
             check: "storage_duration_tier IN ('PERMANENT', 'FARMING', 'PRODUCTS')"
           )

    create constraint(:activities, :valid_activity_status,
             check:
               "status IN ('REGISTERED', 'ACTIVE', 'MONITORING', 'COMPLETED', 'CERTIFIED', 'CLOSED')"
           )
  end
end
