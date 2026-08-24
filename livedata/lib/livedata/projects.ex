defmodule Livedata.Projects do
  @moduledoc "Context for project queries."
  import Ecto.Query

  alias Livedata.Measurements.RawMeasurement
  alias Livedata.ProjectParcels
  alias Livedata.Repo
  alias Livedata.Projects.Methodology
  alias Livedata.Projects.{Activity, Project}

  @doc "Lists projects, newest first (all — auth is out of scope)."
  @spec list_projects() :: [%Project{}]
  def list_projects do
    Repo.all(from p in Project, order_by: [desc: p.inserted_at])
  end

  @spec get_project!(binary()) :: %Project{}
  def get_project!(id), do: Repo.get!(Project, id)

  @doc "Portfolio roll-up — parcel/activity/measurement counts + last_measured_at, newest first."
  @spec list_projects_with_stats() :: [map()]
  def list_projects_with_stats do
    parcel_counts = ProjectParcels.count_by_project()
    rollup = activity_rollup_by_project()
    empty = %{activity_count: 0, measurement_count: 0, last_measured_at: nil}

    for project <- list_projects() do
      stats = Map.get(rollup, project.id, empty)

      %{
        id: project.id,
        name: project.name,
        description: project.description,
        status: project.status,
        commissioned_at: project.commissioned_at,
        parcel_count: Map.get(parcel_counts, project.id, 0),
        activity_count: stats.activity_count,
        measurement_count: stats.measurement_count,
        last_measured_at: stats.last_measured_at
      }
    end
  end

  # Measurements hang off activities, never off projects (@req: CRCF-21).
  defp activity_rollup_by_project do
    from(a in Activity,
      left_join: rm in RawMeasurement,
      on: rm.activity_id == a.id,
      group_by: a.project_id,
      select:
        {a.project_id,
         %{
           activity_count: count(a.id, :distinct),
           measurement_count: count(rm.id),
           last_measured_at: max(rm.measured_at)
         }}
    )
    |> Repo.all()
    |> Map.new()
  end

  @doc "Activities with measurement coverage — the shared row shape. (@req: CRCF-21, CRCF-22)"
  @spec list_activities_with_stats(keyword()) :: [map()]
  def list_activities_with_stats(opts \\ []) do
    from(a in Activity,
      join: p in Project,
      on: p.id == a.project_id,
      left_join: rm in RawMeasurement,
      on: rm.activity_id == a.id,
      group_by: [a.id, p.id],
      order_by: [asc: p.name, asc: a.name],
      select: %{
        id: a.id,
        name: a.name,
        description: a.description,
        project_id: p.id,
        project_name: p.name,
        activity_type: a.activity_type,
        storage_duration_tier: a.storage_duration_tier,
        status: a.status,
        activity_period_start: a.activity_period_start,
        activity_period_end: a.activity_period_end,
        monitoring_period_start: a.monitoring_period_start,
        monitoring_period_end: a.monitoring_period_end,
        measurement_count: count(rm.id),
        last_measured_at: max(rm.measured_at)
      }
    )
    |> filter_by_project(opts[:project_id])
    |> Repo.all()
  end

  defp filter_by_project(query, nil), do: query
  defp filter_by_project(query, project_id), do: where(query, [a], a.project_id == ^project_id)

  @spec list_methodologies() :: [%Methodology{}]
  def list_methodologies do
    Methodology |> order_by(asc: :name) |> Repo.all()
  end

  @doc "Activities for selection UIs, joined with project name."
  @spec list_activities() :: [%{id: binary(), name: String.t(), project_name: String.t()}]
  def list_activities do
    from(a in Activity,
      join: p in Project,
      on: a.project_id == p.id,
      order_by: [asc: p.name, asc: a.name],
      select: %{id: a.id, name: a.name, project_name: p.name}
    )
    |> Repo.all()
  end
end
