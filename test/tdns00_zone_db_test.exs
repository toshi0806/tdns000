defmodule TDNS00.ZoneDBTest do
  use ExUnit.Case

  @wiki_zone %{
    :soa => %{
      mname: "ns.example.com.",
      rname: "username.example.com.",
      serial: 2016_02_22_01,
      refresh: 24 * 3600,
      retry: 2 * 3600,
      expire: 4 * 7 * 24 * 3600,
      minimum: 3600
    },
    :ttl => 3600,
    "example.com." => %{
      in: %{
        soa: %{
          mname: "ns.example.com.",
          rname: "username.example.com.",
          serial: 2_016_022_201,
          refresh: 24 * 3600,
          retry: 2 * 3600,
          expire: 4 * 7 * 24 * 3600,
          minimum: 3600
        },
        ns: [
          %{
            ttl: 3600,
            rdata: "ns.example.com."
          },
          %{
            ttl: 3600,
            rdata: "ns.somewhere.example."
          }
        ],
        mx: [
          %{
            ttl: 3600,
            rdata: %{
              preference: 10,
              exchange: "mail.example.com."
            }
          },
          %{
            ttl: 3600,
            rdata: %{
              preference: 20,
              exchange: "mail2.example.com."
            }
          },
          %{
            ttl: 3600,
            rdata: %{
              preference: 50,
              exchange: "mail3.example.com."
            }
          }
        ]
      }
    },
    "ns.example.com." => %{
      in: %{
        a: [
          %{
            ttl: 3600,
            rdata: "192.0.2.2"
          }
        ],
        aaaa: [
          %{
            ttl: 3600,
            rdata: "2001:db8:10::2"
          }
        ]
      }
    },
    "www.example.com." => %{
      in: %{
        cname: [
          %{
            ttl: 3600,
            rdata: "example.com."
          }
        ]
      }
    },
    "wwwtest.example.com." => %{
      in: %{
        cname: [
          %{
            ttl: 3600,
            rdata: "www.example.com."
          }
        ]
      }
    },
    "mail.example.com." => %{in: %{a: [%{ttl: 3600, rdata: "192.0.2.3"}]}},
    "mail2.example.com." => %{in: %{a: [%{ttl: 3600, rdata: "192.0.2.4"}]}},
    "mail3.example.com." => %{in: %{a: [%{ttl: 3600, rdata: "192.0.2.5"}]}}
  }

  test "resolve success" do
    assert TDNS00.ZoneDB.resolve("ns.example.com.", :in, :a) ==
             %{
               "ns.example.com." => %{
                 in: %{a: [%{rdata: IP.Address.from_string!("192.0.2.2"), ttl: 3600}]}
               }
             }

    assert TDNS00.ZoneDB.resolve("mail.example.com.", :in, :a) ==
             %{
               "mail.example.com." => %{
                 in: %{a: [%{rdata: IP.Address.from_string!("192.0.2.3"), ttl: 3600}]}
               }
             }

    assert TDNS00.ZoneDB.resolve("wwwtest.example.com.", :in, :cname) ==
             %{
               "wwwtest.example.com." => %{
                 in: %{cname: [%{rdata: "www.example.com.", ttl: 3600}]}
               }
             }
  end

  test "resolve fail" do
    assert TDNS00.ZoneDB.resolve("nx_domain.example.com.", :in, :a) ==
             %{"nx_domain.example.com." => %{error: :nx_domain}}

    assert TDNS00.ZoneDB.resolve("ns.example.com.", :in, :txt) ==
             %{"ns.example.com." => %{in: %{soa: [%{rdata: @wiki_zone.soa, ttl: @wiki_zone.ttl}]}}}

    assert TDNS00.ZoneDB.resolve("ns.example.com.", :ch, :a) ==
             %{"ns.example.com." => %{ch: %{soa: [%{rdata: @wiki_zone.soa, ttl: @wiki_zone.ttl}]}}}
  end
end
