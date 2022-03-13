defmodule TDNS00.ZoneDBTest do
  use ExUnit.Case

  @wiki_zone %{
    :soa => [
      %{
        ttl: 3600,
        mname: "ns.example.com.",
        rname: "username.example.com.",
        serial: 2_016_022_201,
        refresh: 24 * 3600,
        retry: 2 * 3600,
        expire: 4 * 7 * 24 * 3600,
        minimum: 3600
      }
    ],
    :ttl => 3600,
    "example.com." => %{
      in: %{
        soa: [
          %{
            ttl: 3600,
            mname: "ns.example.com.",
            rname: "username.example.com.",
            serial: 2_016_022_201,
            refresh: 24 * 3600,
            retry: 2 * 3600,
            expire: 4 * 7 * 24 * 3600,
            minimum: 3600
          }
        ],
        ns: [
          %{
            ttl: 3600,
            name: "ns.example.com."
          },
          %{
            ttl: 3600,
            name: "ns.somewhere.example."
          }
        ],
        mx: [
          %{
            ttl: 3600,
            preference: 10,
            name: "mail.example.com."
          },
          %{
            ttl: 3600,
            preference: 20,
            name: "mail2.example.com."
          },
          %{
            ttl: 3600,
            preference: 50,
            name: "mail3.example.com."
          }
        ]
      }
    },
    "ns.example.com." => %{
      in: %{
        a: [
          %{
            ttl: 3600,
            addr: {192, 0, 2, 2}
          }
        ],
        aaaa: [
          %{
            ttl: 3600,
            addr: '2001:db8:10::2' |> :inet.parse_address() |> Tuple.to_list() |> List.last()
          }
        ]
      }
    },
    "www.example.com." => %{
      in: %{
        cname: [
          %{
            ttl: 3600,
            name: "example.com."
          }
        ]
      }
    },
    "wwwtest.example.com." => %{
      in: %{
        cname: [
          %{
            ttl: 3600,
            name: "www.example.com."
          }
        ]
      }
    },
    "mail.example.com." => %{in: %{a: [%{ttl: 3600, addr: {192, 0, 2, 3}}]}},
    "mail2.example.com." => %{in: %{a: [%{ttl: 3600, addr: {192, 0, 2, 4}}]}},
    "mail3.example.com." => %{in: %{a: [%{ttl: 3600, addr: {192, 0, 2, 5}}]}}
  }

  test "resolve success" do
    assert TDNS00.ZoneDB.resolve("example.com.", :in, :soa) ==
             %{
               name: "example.com.",
               class: :in,
               type: :soa,
               rdata: [
                 %{
                   mname: "ns.example.com.",
                   rname: "username.example.com.",
                   serial: 2016_02_22_01,
                   refresh: 24 * 3600,
                   retry: 2 * 3600,
                   expire: 4 * 7 * 24 * 3600,
                   minimum: 3600,
                   ttl: @wiki_zone.ttl
                 }
               ]
             }

    assert TDNS00.ZoneDB.resolve("ns.example.com.", :in, :a) ==
             %{
               name: "ns.example.com.",
               class: :in,
               type: :a,
               rdata: [
                 %{addr: {192, 0, 2, 2}, ttl: 3600}
               ]
             }

    assert TDNS00.ZoneDB.resolve("mail.example.com.", :in, :a) ==
             %{
               name: "mail.example.com.",
               class: :in,
               type: :a,
               rdata: [
                 %{addr: {192, 0, 2, 3}, ttl: 3600}
               ]
             }

    assert TDNS00.ZoneDB.resolve("wwwtest.example.com.", :in, :cname) ==
             %{
               name: "wwwtest.example.com.",
               class: :in,
               type: :cname,
               rdata: [
                 %{name: "www.example.com.", ttl: 3600}
               ]
             }

    assert TDNS00.ZoneDB.resolve("example.com.", :in, :mx) ==
             %{
               name: "example.com.",
               class: :in,
               type: :mx,
               rdata: [
                 %{preference: 10, name: "mail.example.com.", ttl: 3600},
                 %{preference: 20, name: "mail2.example.com.", ttl: 3600},
                 %{preference: 50, name: "mail3.example.com.", ttl: 3600}
               ]
             }
  end

  test "resolve fail" do
    assert TDNS00.ZoneDB.resolve("nx_domain.example.com.", :in, :a) ==
             %{name: "nx_domain.example.com.", error: :nx_domain}

    assert TDNS00.ZoneDB.resolve("ns.example.com.", :ch, :a) ==
             %{name: "ns.example.com.", class: :ch, error: :nx_class}

    assert TDNS00.ZoneDB.resolve("ns.example.com.", :in, :txt) ==
             %{name: "ns.example.com.", class: :in, type: :txt, error: :nx_type}

  end
end
