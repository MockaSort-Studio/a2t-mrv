defmodule LivedataWeb.WallabyCase do
  @moduledoc """
  Test case template for end-to-end browser tests using Wallaby.

  Tag tests with `@tag :e2e` — they are excluded from the default suite and
  only run under `mix test --only e2e`.

  `use Wallaby.Feature` handles sandbox checkout and session lifecycle automatically
  when `config :wallaby, otp_app: :livedata` is set and `Livedata.Repo` is in
  `:ecto_repos`. The `Phoenix.Ecto.SQL.Sandbox` plug in `LivedataWeb.Endpoint`
  (gated by `:sql_sandbox` config) ensures browser requests land on the same
  sandbox connection as the test process.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use Wallaby.Feature

      import Wallaby.Query
      import Livedata.Fixtures
    end
  end
end
