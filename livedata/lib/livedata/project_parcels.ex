defmodule Livedata.ProjectParcels do
  @moduledoc "Context for project parcel queries."
  import Ecto.Query

  alias Livedata.ProjectParcels.ProjectParcel
  alias Livedata.Projects.Project
  alias Livedata.Repo

  @doc """
  Lists parcels together with the name of the project they belong to, newest
  project first. Parcels are the only place a spatial boundary is recorded
  (@req: CRCF-37), so this is what the dashboard map renders. (@req: KR 2.1)
  """
  @spec list_parcels_with_project() :: [map()]
  def list_parcels_with_project do
    Repo.all(
      from pp in ProjectParcel,
        join: p in Project,
        on: p.id == pp.project_id,
        order_by: [desc: p.inserted_at, asc: pp.parcel_ref],
        select: %{
          project_id: p.id,
          project_name: p.name,
          parcel_ref: pp.parcel_ref,
          boundary: pp.boundary
        }
    )
  end
end
