defmodule TDNS00.DNSWorker do
  def worker({host, port, packet}, socket) do
    packet
    |> DNSpacket.parse()
    |> resolve_query()
    |> DNSpacket.create()
    |> send_reply(socket, host, port)
  end

  def resolve_query(packet) do
    packet
    |> Map.put(:qr, 1)
    |> resolve_query_sub()
  end

  defp resolve_query_sub(packet) do
    q = hd(packet.question)

    case resolve(q, []) do
      {:ok, []} ->
        %{
          packet
          | authority:
              TDNS00.ZoneDB.origin() |> TDNS00.ZoneDB.resolve(:in, :soa) |> expand_answer()
        }

      {:ok, result} ->
        %{packet | answer: result}

      {:error, :nx_domain} ->
        %{packet | rcode: 3}
    end
  end

  def resolve(%{qname: qname, qclass: qclass, qtype: qtype}, acc) do
    case TDNS00.ZoneDB.resolve(qname, qclass, qtype) do
      %{error: :nx_domain} ->
        if (length(acc)) == 0 do
          {:error, :nx_domain}
        else
          {:ok, expand_answer_list(acc)}
        end

      %{error: :nx_class} ->
        {:ok, expand_answer_list(acc)}

      %{error: :nx_type, type: :cname} ->
        {:ok, expand_answer_list(acc)}

      %{error: :nx_type} ->
        case TDNS00.ZoneDB.resolve(qname, qclass, :cname) do
          %{error: :nx_type} ->
            {:ok, expand_answer_list(acc)}

          cname_rr ->
            resolve(
              %{qname: cname_rr.rdata |> hd |> Map.get(:name), qclass: qclass, qtype: qtype},
              [cname_rr | acc]
            )
        end

      result ->
        {:ok, expand_answer_list([result | acc])}
    end
  end

  def expand_answer(answer) do
    Enum.map(answer.rdata, fn n ->
      answer
      |> Map.drop([:rdata])
      |> Map.put(:rdata, Map.drop(n, [:ttl]))
      |> Map.put(:ttl, n.ttl)
    end)
  end

  def expand_answer_list(answer) do
    answer
    |> Enum.map(fn i -> expand_answer(i) end)
    |> Enum.reduce([], fn i, acc -> i ++ acc end)
  end

  def send_reply(packet, socket, host, port) do
    :gen_udp.send(socket, host, port, packet)
  end
end
