ExUnit.start(exclude: [:e2e])

if System.find_executable("chromedriver") do
  {:ok, _} = Application.ensure_all_started(:wallaby)
end

Ecto.Adapters.SQL.Sandbox.mode(Livedata.Repo, :manual)
