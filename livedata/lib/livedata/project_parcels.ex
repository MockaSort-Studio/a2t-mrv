defmodule Livedata.ProjectParcels do
  @moduledoc "Context for project parcel queries."
  import Ecto.Query

  alias Livedata.Geo.GeoJSON
  alias Livedata.ProjectParcels.ProjectParcel
  alias Livedata.Projects.Project
  alias Livedata.Repo

  @doc "Parcels with project name, newest project first. (@req: CRCF-37, KR 2.1)"
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

  @doc "Parcels for one project, same shape as list_parcels_with_project/0."
  @spec list_parcels_for_project(binary()) :: [map()]
  def list_parcels_for_project(project_id) do
    Repo.all(
      from pp in ProjectParcel,
        join: p in Project,
        on: p.id == pp.project_id,
        where: pp.project_id == ^project_id,
        order_by: [asc: pp.parcel_ref],
        select: %{
          project_id: p.id,
          project_name: p.name,
          parcel_ref: pp.parcel_ref,
          boundary: pp.boundary,
          inserted_at: pp.inserted_at
        }
    )
  end

  @doc "Parcel count keyed by project_id; projects without parcels are absent."
  @spec count_by_project() :: %{binary() => non_neg_integer()}
  def count_by_project do
    Repo.all(
      from pp in ProjectParcel,
        group_by: pp.project_id,
        select: {pp.project_id, count(pp.id)}
    )
    |> Map.new()
  end

  @doc "GeoJSON FeatureCollection string for the map hook. (@req: CRCF-37)"
  @spec feature_collection([map()]) :: String.t()
  def feature_collection(parcels) do
    features =
      for parcel <- parcels do
        %{
          "type" => "Feature",
          "geometry" => GeoJSON.encode_geometry(parcel.boundary),
          "properties" => %{
            "project_id" => parcel.project_id,
            "name" => parcel.project_name,
            "parcel_ref" => parcel.parcel_ref
          }
        }
      end

    Jason.encode!(%{"type" => "FeatureCollection", "features" => features})
  end
end
