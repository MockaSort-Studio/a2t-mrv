defmodule Livedata.Repo do
  use Ecto.Repo,
    otp_app: :livedata,
    adapter: Ecto.Adapters.Postgres
end
