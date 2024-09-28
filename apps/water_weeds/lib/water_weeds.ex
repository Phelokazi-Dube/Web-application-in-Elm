defmodule WaterWeeds.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Start a worker by calling: WaterWeeds.Worker.start_link(arg)
      # {WaterWeeds.Worker, arg}
      WaterWeeds.MongoDBClient
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WaterWeeds.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
