defmodule MatrixPortal.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    Supervisor.start_link([Cfg], strategy: :one_for_one, name: MatrixPortal.CfgSupervisor)

    children = [
      Matrix,
      MatrixPortalWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:matrix_portal, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: MatrixPortal.PubSub},
      # Start a worker by calling: MatrixPortal.Worker.start_link(arg)
      # {MatrixPortal.Worker, arg},
      # Start to serve requests, typically the last entry
      MatrixPortalWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: MatrixPortal.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    MatrixPortalWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
