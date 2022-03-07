defmodule TDNS00.DNSWorker do
  def worker({host, port, packet}, socket) do
    query = packet |> DNSpacket.parse() # |> IO.inspect(label: "query")

    # resolve 1st query only
    %{qname: qname, qclass: qclass, qtype: qtype} = query.question |> hd

    # compile answer
    %{
      id: query.id,
      # FIXME
      flags: 0x100,
      question: query.question,
      answer: TDNS00.ZoneDB.resolve(qname, qclass, qtype) |> expand_answer(),
      authority: [],
      # FIXME
      additional: []
    }
    #    |> IO.inspect(label: "answer")
    |> DNSpacket.create()
    |> send_reply(socket, host, port)
  end

  def expand_answer(answer) do
    Enum.map(answer.rdata, fn n ->
      answer
      |> Map.drop([:rdata])
      |> Map.put(:rdata, n)
      |> Map.put(:ttl, n.ttl)
    end)
  end

  def send_reply(packet, socket, host, port) do
    :gen_udp.send(socket, host, port, packet)
  end
end
