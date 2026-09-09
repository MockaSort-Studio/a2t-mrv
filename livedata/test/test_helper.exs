ExUnit.start(exclude: [:e2e])
Ecto.Adapters.SQL.Sandbox.mode(Livedata.Repo, :manual)
Application.put_env(:wallaby, :base_url, LivedataWeb.Endpoint.url())
