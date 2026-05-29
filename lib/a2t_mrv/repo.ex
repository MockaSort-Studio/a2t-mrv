defmodule A2tMrv.Repo do
  use Ecto.Repo,
    otp_app: :a2t_mrv,
    adapter: Ecto.Adapters.Postgres
end
