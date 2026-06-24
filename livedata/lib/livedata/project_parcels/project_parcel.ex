defmodule Livedata.ProjectParcels.ProjectParcel do
  use Ecto.Schema
  import Ecto.Changeset
  import Livedata.Geo.Validations

  @moduledoc """
  Schema and changesets for project parcels.

  Stores a snapshot of a parcel's geometry and registry reference at project
  commissioning time. The boundary and data source are immutable once recorded —
  LPIS/CADASTER geometries change over time; the boundary that matters for a
  carbon credit is the one captured at commissioning. (@req: CRCF-36)
  """

  @valid_data_sources ~w(LPIS CADASTER)
  # @req: CRCF-19
  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "project_parcels" do
    field :project_id, :binary_id
    field :parcel_ref, :string
    # @req: CRCF-36
    field :data_source, :string
    # @req: CRCF-37
    field :boundary, Geo.PostGIS.Geometry
    # for future use when we add the steward/community table
    field :operator_id, :binary_id
    # @req: CRCF-20
    field :commissioned_at, :utc_datetime_usec

    # @req: CRCF-20
    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for creating a project parcel. Boundary and project association
  are set once and never updated.
  """
  def create_changeset(project_parcel, project_id, attrs) do
    project_parcel
    |> cast(attrs, [:parcel_ref, :data_source, :boundary, :commissioned_at])
    |> put_change(:project_id, project_id)
    |> validate_required([:project_id, :parcel_ref, :data_source, :boundary, :commissioned_at])
    |> validate_inclusion(:data_source, @valid_data_sources)
    |> foreign_key_constraint(:project_id)
    |> validate_spatial_boundary(:boundary)
  end
end
