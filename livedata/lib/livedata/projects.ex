defmodule Livedata.Projects do
  @moduledoc "Context for project queries."
  import Ecto.Query

  alias Livedata.Repo
  alias Livedata.Projects.Methodology
  alias Livedata.Projects.Project

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
end
