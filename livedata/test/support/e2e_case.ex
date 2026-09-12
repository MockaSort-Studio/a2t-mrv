defmodule LivedataWeb.E2ECase do
  @moduledoc """
  ExUnit case template for browser-driven end-to-end tests.

  Uses Wallaby for browser control and wires the Ecto SQL sandbox so the browser
  session sees rows inserted by the test's setup block.

  Tag tests with `@tag :e2e` — they are excluded from the default `mix test` run
  and only run when `mix test --only e2e` is invoked.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      use Wallaby.Feature

      import Wallaby.Query
      import Livedata.Fixtures

      alias Livedata.Repo
    end
  end

end
