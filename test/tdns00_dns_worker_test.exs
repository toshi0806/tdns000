defmodule TDNS00.DNSWorkerTest do
  use ExUnit.Case

  test "nx domain" do
    assert %DNSpacket{
             id: 0x1825,
             qr: 0,
             question: [%{qname: "nx.example.com.", qclass: :in, qtype: :txt}]
           }
           |> TDNS00.DNSWorker.resolve_query() ==
             %DNSpacket{
               id: 0x1825,
               qr: 1,
               # NX Domain
               rcode: 3,
               question: [%{qname: "nx.example.com.", qclass: :in, qtype: :txt}]
             }
  end

  test "nx type" do
    assert %DNSpacket{
             id: 0x1825,
             question: [%{qname: "example.com.", qclass: :in, qtype: :txt}]
           }
           |> TDNS00.DNSWorker.resolve_query() ==
             %DNSpacket{
               id: 0x1825,
               qr: 1,
               rcode: 0,
               question: [%{qname: "example.com.", qclass: :in, qtype: :txt}],
               answer: [],
               authority: [
                 %{
                   name: "example.com.",
                   class: :in,
                   type: :soa,
                   ttl: 3600,
                   rdata: %{
                     mname: "ns.example.com.",
                     rname: "username.example.com.",
                     serial: 2016_02_22_01,
                     refresh: 24 * 3600,
                     retry: 2 * 3600,
                     expire: 4 * 7 * 24 * 3600,
                     minimum: 3600
                   }
                 }
               ]
             }
  end

  test "success" do
    q = %DNSpacket{
      id: 0x1825,
      qr: 0,
      question: [%{qname: "example.com.", qclass: :in, qtype: :a}]
    }

    a = %DNSpacket{
      id: 0x1825,
      qr: 1,
      rcode: 0,
      question: [%{qname: "example.com.", qclass: :in, qtype: :a}],
      answer: [
        %{
          name: "example.com.",
          class: :in,
          type: :a,
          ttl: 3600,
          rdata: %{
            addr: {192, 0, 2, 1}
          }
        }
      ]
    }

    assert TDNS00.DNSWorker.resolve_query(q) == a
  end
end
