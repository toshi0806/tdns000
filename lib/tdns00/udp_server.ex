defmodule TDNS00.UDPServer do
  require Logger

  def open(port), do: open(port, :inet6)

  def open(port, family) do
    {:ok, socket} = :gen_udp.open(port, [:binary, family, active: false, reuseaddr: true])

    receiver(socket)
  end

  def receiver(socket) do
    {:ok, data} = :gen_udp.recv(socket, 0)

    {:ok, _pid} =
      Task.Supervisor.start_child(TDNS00.UDPServer.WorkerSupervisor, TDNS00.DNSWorker, :worker, [
        data,
        socket
      ])

    receiver(socket)
  end
end
