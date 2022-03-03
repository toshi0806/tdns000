defmodule TDNS00.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("TDNS00PORT") || "53")

    children = [
      {TDNS00.ZoneDB, "test/wiki.zone"},
      {Task.Supervisor, name: TDNS00.UDPServer.WorkerSupervisor},
      {TDNS00.UDPServer.Task, port}
    ]

    opts = [strategy: :one_for_one, name: TDNS00.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
