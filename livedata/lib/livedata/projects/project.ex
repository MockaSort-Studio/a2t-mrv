defmodule Livedata.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_statuses ~w(DRAFT COMMISSIONED ACTIVE MONITORING CERTIFIED CLOSED)

  # @req: CRCF-19
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # @req: CRCF-21
  schema "projects" do
    field :name, :string
    field :description, :string
    field :status, :string, default: "DRAFT"
    field :operator_id, :binary_id
    # @req: CRCF-20
    field :commissioned_at, :utc_datetime_usec

    # @req: CRCF-20
    timestamps(type: :utc_datetime_usec)
  end

  # Spatial boundaries live on `project_parcels` only — a project's geometry is
  # the union of the parcel boundaries captured at commissioning. (@req: CRCF-37)
  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :description, :status, :commissioned_at])
    |> validate_required([:name, :status, :commissioned_at])
    |> validate_inclusion(:status, @valid_statuses)
  end
end
