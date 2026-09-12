ExUnit.start(exclude: [:e2e])
Ecto.Adapters.SQL.Sandbox.mode(Livedata.Repo, :manual)

chromedriver_works =
  case System.find_executable("chromedriver") do
    nil -> false
    path -> match?({_, 0}, System.cmd(path, ["--version"], stderr_to_stdout: true))
  end

if chromedriver_works do
  {:ok, _} = Application.ensure_all_started(:wallaby)
end
