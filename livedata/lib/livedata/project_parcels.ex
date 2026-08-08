defmodule Livedata.ProjectParcels do
  @moduledoc "Context for project parcel queries."
  import Ecto.Query

  alias Livedata.Geo.GeoJSON
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

  @doc """
  Lists the parcels of a single project, in the same shape as
  `list_parcels_with_project/0` so both can feed `feature_collection/1`.
  """
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
          data_source: pp.data_source,
          boundary: pp.boundary,
          recorded_at: pp.commissioned_at
        }
    )
  end

  @doc """
  Counts parcels per project, keyed by `project_id`. Projects without parcels
  are absent from the map.
  """
  @spec count_by_project() :: %{binary() => non_neg_integer()}
  def count_by_project do
    Repo.all(
      from pp in ProjectParcel,
        group_by: pp.project_id,
        select: {pp.project_id, count(pp.id)}
    )
    |> Map.new()
  end

  @doc """
  Encodes parcel rows as a GeoJSON `FeatureCollection` string for the map hook.
  Boundaries are recorded on parcels, so the map is drawn from parcel geometry,
  labelled with the project each parcel belongs to. (@req: CRCF-37)
  """
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
