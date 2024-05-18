defmodule Fluffy.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start the Telemetry supervisor
      FluffyWeb.Telemetry,
      # Start the PubSub system
      {Phoenix.PubSub, name: Fluffy.PubSub},
      # Start Finch
      {Finch, name: Fluffy.Finch},
      # Start the Endpoint (http/https)
      FluffyWeb.Endpoint,
      # Start a worker by calling: Fluffy.Worker.start_link(arg)
      # {Fluffy.Worker, arg}
      # Fluffy.CouchDBClient
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Fluffy.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    FluffyWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
