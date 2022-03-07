defmodule TDNS00.UDPServer.Task do
  use Task

  def start_link(arg) do
    Task.start_link(__MODULE__, :udp_server_start, [arg])
  end

  def udp_server_start(arg) do
    TDNS00.UDPServer.open(arg)
  end
end
