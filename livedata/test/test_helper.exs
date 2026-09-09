ExUnit.start(exclude: [:e2e])
{:ok, _} = Application.ensure_all_started(:wallaby)
Ecto.Adapters.SQL.Sandbox.mode(Livedata.Repo, :manual)
