defmodule Livedata.Release do
  @moduledoc """
  Tasks that need to run inside an assembled release, where Mix is unavailable.

  Invoked through the `bin/migrate` and `bin/seed` overlay scripts (see
  `rel/README.md`), which the Render start command chains ahead of `bin/server`.
  See `docs/contributing/deployment.md`.
  """

  @app :livedata

  @doc "Runs all pending migrations for every configured repo."
  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  @doc "Rolls `repo` back to `version`."
  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  @doc """
  Runs `priv/repo/seeds.exs`.

  Chained into the platform start command, so this runs on **every** boot —
  which is the constraint to design seeds around: guard inserts with
  `Repo.exists?/1` or an upsert, never a bare `insert!`.

  Today `seeds.exs` seeds nothing and this is a no-op. It is wired up from the
  start because a reference table that forms depend on cannot be created by a
  migration and then left to a human to populate on every new database — and
  the failure mode when that is forgotten is a form that renders with an empty
  picker rather than anything that looks like a deployment problem.
  """
  def seed do
    load_app()

    for repo <- repos() do
      {:ok, _, _} =
        Ecto.Migrator.with_repo(repo, fn _repo ->
          Code.eval_file(Application.app_dir(@app, "priv/repo/seeds.exs"))
        end)
    end
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Managed Postgres (Neon) requires TLS, and `Application.load/1` does not
    # start :ssl the way booting the endpoint would. Without this, `bin/migrate`
    # hangs instead of connecting.
    {:ok, _} = Application.ensure_all_started(:ssl)
    Application.load(@app)
  end
end
