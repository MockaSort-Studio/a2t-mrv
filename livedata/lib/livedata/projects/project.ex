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
    # @req: CRCF-37
    field :spatial_boundary, Geo.PostGIS.Geometry
    field :operator_id, :binary_id
    # @req: CRCF-20
    field :commissioned_at, :utc_datetime_usec

    # @req: CRCF-20
    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :description, :status, :spatial_boundary, :commissioned_at])
    |> validate_required([:name, :status, :spatial_boundary, :commissioned_at])
    |> validate_inclusion(:status, @valid_statuses)
    |> validate_spatial_boundary()
  end

  defp validate_spatial_boundary(changeset) do
    case Ecto.Changeset.get_field(changeset, :spatial_boundary) do
      nil ->
        changeset

      %Geo.MultiPolygon{srid: 4326} ->
        changeset

      %Geo.MultiPolygon{} ->
        add_error(changeset, :spatial_boundary, "must use SRID 4326")

      _ ->
        add_error(changeset, :spatial_boundary, "must be a MultiPolygon with SRID 4326")
    end
  end
end
