defmodule Livedata.Projects do
  @moduledoc "Context for project queries."
  import Ecto.Query

  alias Livedata.Repo
  alias Livedata.Projects.Methodology
  alias Livedata.Projects.{Activity, Project}

  @doc """
  Lists projects, newest first. Auth is out of scope, so this returns all
  projects (single-operator world until operator auth lands).
  """
  @spec list_projects() :: [%Project{}]
  def list_projects do
    Repo.all(from p in Project, order_by: [desc: p.inserted_at])
  end

  @doc """
  Lists methodologies, ordered by name.
  """
  @spec list_methodologies() :: [%Methodology{}]
  def list_methodologies do
    Methodology |> order_by(asc: :name) |> Repo.all()
  end

  @doc """
  Lists activities for use in selection UIs, joined with their project name.
  `Activity.project_id` is a plain field (not a `belongs_to`), so this joins
  rather than preloads.
  """
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
