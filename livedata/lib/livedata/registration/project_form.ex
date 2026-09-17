defmodule Livedata.Registration.ProjectForm do
  @moduledoc """
  Embedded schema for the project + parcel step of registration.
  Activity creation is separate (@req: CRCF-34).
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Livedata.Geo.Validations

  @data_sources ~w(LPIS CADASTER)
  @required ~w(project_name parcel_ref parcel_data_source parcel_boundary_geojson)a
  @optional [:project_description]

  @primary_key false
  embedded_schema do
    field :project_name, :string
    field :project_description, :string
    field :parcel_ref, :string
    field :parcel_data_source, :string
    field :parcel_boundary_geojson, :string
  end

  def changeset(form, attrs) do
    form
    |> cast(attrs, @required ++ @optional)
    |> validate_required(@required)
    # @req: CRCF-36
    |> validate_inclusion(:parcel_data_source, @data_sources)
    # @req: CRCF-37
    |> Validations.validate_geojson_multipolygon(:parcel_boundary_geojson)
  end
end
