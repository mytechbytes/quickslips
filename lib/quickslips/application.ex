defmodule QuickSlips.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      QuickSlipsWeb.Telemetry,
      QuickSlips.Repo,
      QuickSlips.Templates.Registry,
      {DNSCluster, query: Application.get_env(:quickslips, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: QuickSlips.PubSub},
      # For work that should not hold a visitor up, like the e-mails that follow a message of the contact form.
      {Task.Supervisor, name: QuickSlips.TaskSupervisor},
      # Start a worker by calling: QuickSlips.Worker.start_link(arg)
      # {QuickSlips.Worker, arg},
      # Start to serve requests, typically the last entry
      QuickSlipsWeb.Endpoint
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: QuickSlips.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    QuickSlipsWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
