defmodule TDNS00.ZoneParser do
  def parse_file(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> parse_zone(%{}, %{})
  end

  def paren_reader([top | body], "") do
    line_real = Regex.replace(~r/\s*;.*/, top, "")

    if Regex.match?(~r/\(/, line_real) do
      if Regex.match?(~r/\)/, line_real) do
        {line_real |> String.replace("(", "") |> String.replace(")", ""), body}
      else
        paren_reader(body, String.replace(line_real, "(", "") <> " ")
      end
    else
      {line_real, body}
    end
  end

  def paren_reader([top | body], line) do
    line_real = Regex.replace(~r/\s*;.*/, top, "")

    if Regex.match?(~r/\)/, line_real) do
      {line <> " " <> String.replace(line_real, ")", ""), body}
    else
      paren_reader(body, line <> " " <> line_real)
    end
  end

  def parse_zone([], _current, zone), do: zone

  def parse_zone(body, current, zone) do
    {line_body, left} = paren_reader(body, "")

    args = String.split(line_body)

    cond do
      Regex.match?(~r/^$/, line_body) ->
        parse_zone(left, current, zone)

      Regex.match?(~r/^\$/, line_body) ->
        parse_dollar(args, left, zone)

      Regex.match?(~r/^\S/, line_body) ->
        parse_ttl(
          tl(args),
          left,
          Map.put(current, :host, args |> hd |> get_fqdn(zone.origin)),
          zone
        )

      true ->
        parse_ttl(args, left, current, zone)
    end
  end

  def parse_dollar(["$ORIGIN", value], left, zone) do
    parse_zone(left, %{}, Map.put(zone, :origin, value))
  end

  def parse_dollar(["$TTL", value], left, zone) do
    parse_zone(left, %{}, Map.put(zone, :ttl, parse_time(value)))
  end

  def parse_time(time) do
    parsed = Regex.named_captures(~r/(?<num>\d+)(?<unit>[MHDW]?)/, String.upcase(time))

    String.to_integer(parsed["num"]) *
      case parsed["unit"] do
        "M" -> 60
        "H" -> 3600
        "D" -> 86400
        "W" -> 604_800
        _ -> 1
      end
  end

  def get_fqdn("@", origin) do
    origin
  end

  def get_fqdn(host, origin) do
    if Regex.match?(~r/\.$/, host) do
      host
    else
      host <> "." <> origin
    end
  end

  def parse_ttl([ttl | args] = arg0, left, current, zone) do
    if Regex.match?(~r/\d+/, ttl) do
      parse_class(args, left, Map.put(current, :ttl, parse_time(ttl)), zone)
    else
      parse_class(arg0, left, Map.put(current, :ttl, zone.ttl), zone)
    end
  end

  def parse_class(["IN" | args], left, current, zone) do
    parse_type(args, left, Map.put(current, :class, :in), zone)
  end

  def parse_class(["CS" | args], left, current, zone) do
    parse_zone(left, %{host: current.host}, Map.put(zone, current.host, %{cs: %{rdata: args}}))
  end

  def parse_class(["CH" | args], left, current, zone) do
    parse_zone(left, %{host: current.host}, Map.put(zone, current.host, %{ch: %{rdata: args}}))
  end

  def parse_class(["HS" | args], left, current, zone) do
    parse_zone(left, %{host: current.host}, Map.put(zone, current.host, %{hs: %{rdata: args}}))
  end

  def parse_class(args, left, current, zone) do
    parse_type(args, left, Map.put(current, :class, :in), zone)
  end

  def parse_type(
        ["SOA" | [mname | [rname | [serial | [refresh | [retry | [expire | [minimum | _]]]]]]]],
        left,
        current,
        zone
      ) do
    soa = %{
      mname: get_fqdn(mname, zone.origin),
      rname: get_fqdn(rname, zone.origin),
      serial: parse_time(serial),
      refresh: parse_time(refresh),
      retry: parse_time(retry),
      expire: parse_time(expire),
      minimum: parse_time(minimum)
    }

    parse_zone(
      left,
      %{host: current.host},
      add_rdata(
        Map.put(zone, :soa, soa),
        current
        |> Map.put(:type, :soa)
        |> Map.put(:rdata, soa)
      )
    )
  end

  def parse_type(["NS" | [ns | _]], left, current, zone) do
    parse_zone(
      left,
      %{host: current.host},
      add_rdata(
        zone,
        current
        |> Map.put(:type, :ns)
        |> Map.put(:rdata, get_fqdn(ns, zone.origin))
      )
    )
  end

  def parse_type(["A" | [addr | _]], left, current, zone) do
    parse_zone(
      left,
      %{host: current.host},
      add_rdata(
        zone,
        current
        |> Map.put(:type, :a)
        |> Map.put(:rdata, IP.Address.from_string!(addr))
      )
    )
  end

  def parse_type(["AAAA" | [addr | _]], left, current, zone) do
    parse_zone(
      left,
      %{host: current.host},
      add_rdata(
        zone,
        current
        |> Map.put(:type, :aaaa)
        |> Map.put(:rdata, IP.Address.from_string!(addr))
      )
    )
  end

  def parse_type(["CNAME" | [cname | _]], left, current, zone) do
    parse_zone(
      left,
      %{host: current.host},
      add_rdata(
        zone,
        current
        |> Map.put(:type, :cname)
        |> Map.put(:rdata, get_fqdn(cname, zone.origin))
      )
    )
  end

  def parse_type(["MX" | [pref | [exchange | _]]], left, current, zone) do
    parse_zone(
      left,
      %{host: current.host},
      add_rdata(
        zone,
        current
        |> Map.put(:type, :mx)
        |> Map.put(:rdata, %{
          pref: String.to_integer(pref),
          exchange: get_fqdn(exchange, zone.origin)
        })
      )
    )
  end

  def add_rdata(zone, current) do
    rdata = %{ttl: current.ttl, rdata: current.rdata}

    Map.update(
      zone,
      current.host,
      %{current.class => %{current.type => [rdata]}},
      fn host_record ->
        Map.update(
          host_record,
          current.class,
          %{current.type => [rdata]},
          fn class_record ->
            Map.update(
              class_record,
              current.type,
              [rdata],
              fn type_record ->
                [rdata | type_record]
              end
            )
          end
        )
      end
    )
  end
end