defmodule LivedataWeb.E2ECase do
  @moduledoc """
  ExUnit case template for browser-driven e2e specs via Wallaby.

  Tags tests `:e2e` so the default `mix test` run skips them.
  The SQL sandbox runs in shared mode so the browser's requests share
  the test process's checked-out connection.

  Requires chromedriver on PATH and `server: true` in test.exs (both provided
  by #128 and config/test.exs respectively).
  """
  use ExUnit.CaseTemplate

  using do
    quote do
      import Wallaby.Browser
      import Wallaby.Query
    end
  end

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Livedata.Repo)
    Ecto.Adapters.SQL.Sandbox.mode(Livedata.Repo, {:shared, self()})

    metadata = Phoenix.Ecto.SQL.Sandbox.metadata_for(Livedata.Repo, self())
    {:ok, session} = Wallaby.start_session(metadata: metadata)

    on_exit(fn -> Wallaby.end_session(session) end)

    {:ok, session: session}
  end
end
