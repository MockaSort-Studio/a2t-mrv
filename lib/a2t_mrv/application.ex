defmodule A2tMrv.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      A2tMrvWeb.Telemetry,
      A2tMrv.Repo,
      {DNSCluster, query: Application.get_env(:a2t_mrv, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: A2tMrv.PubSub},
      # Start a worker by calling: A2tMrv.Worker.start_link(arg)
      # {A2tMrv.Worker, arg},
      # Start to serve requests, typically the last entry
      A2tMrvWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: A2tMrv.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    A2tMrvWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
