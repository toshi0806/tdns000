defmodule TDNS00.ZoneParser do
  @default_ttl 3600

  @spec parse_file(String.t()) :: any
  def parse_file(path) do
    path
    |> File.read!()
    |> String.split("\n", trim: true)
    |> parse_zone(%{}, %{})
  end

  @spec paren_reader(nonempty_maybe_improper_list, String.t()) :: {String.t(), any}
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

  @spec parse_zone(maybe_improper_list, any, any) :: any
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

  @spec parse_dollar([...], maybe_improper_list, map) :: any
  def parse_dollar(["$ORIGIN", value], left, zone) do
    parse_zone(left, %{}, Map.put(zone, :origin, value))
  end

  def parse_dollar(["$TTL", value], left, zone) do
    parse_zone(left, %{}, Map.put(zone, :ttl, parse_time(value)))
  end

  @spec parse_time(binary) :: integer
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

  @spec get_fqdn(binary, any) :: any
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

  @spec parse_ttl(nonempty_maybe_improper_list, maybe_improper_list, map, map) :: any
  def parse_ttl([ttl | args] = arg0, left, current, zone) do
    if Regex.match?(~r/\d+/, ttl) do
      parse_class(args, left, Map.put(current, :ttl, parse_time(ttl)), zone)
    else
      parse_class(arg0, left, Map.put(current, :ttl, Map.get(zone, :ttl, @default_ttl)), zone)
    end
  end

  @spec parse_class(nonempty_maybe_improper_list, maybe_improper_list, atom | map, map) :: any
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

  @spec parse_type(
          nonempty_maybe_improper_list,
          maybe_improper_list,
          %{:host => any, optional(any) => any},
          map
        ) :: any
  def parse_type(
        ["SOA", mname, rname, serial, refresh, retry, expire, minimum],
        left,
        current,
        zone
      ) do
    parse_zone(
      left,
      %{host: current.host},
      add_rdata(
        zone,
        current
        |> Map.put(:type, :soa)
        |> Map.put(:rdata, %{
          mname: get_fqdn(mname, zone.origin),
          rname: get_fqdn(rname, zone.origin),
          serial: parse_time(serial),
          refresh: parse_time(refresh),
          retry: parse_time(retry),
          expire: parse_time(expire),
          minimum: parse_time(minimum)
        })
      )
    )
  end

  def parse_type(["NS", ns], left, current, zone) do
    parse_zone(
      left,
      %{host: current.host},
      add_rdata(
        zone,
        current
        |> Map.put(:type, :ns)
        |> Map.put(:rdata, %{name: get_fqdn(ns, zone.origin)})
      )
    )
  end

  def parse_type(["A", addr], left, current, zone) do
    parse_zone(
      left,
      %{host: current.host},
      add_rdata(
        zone,
        current
        |> Map.put(:type, :a)
        |> Map.put(
          :rdata,
          %{
            addr:
              addr
              |> String.to_charlist()
              |> :inet.parse_address()
              |> elem(1)
          }
        )
      )
    )
  end

  def parse_type(["AAAA", addr], left, current, zone) do
    parse_zone(
      left,
      %{host: current.host},
      add_rdata(
        zone,
        current
        |> Map.put(:type, :aaaa)
        |> Map.put(
          :rdata,
          %{
            addr:
              addr
              |> String.to_charlist()
              |> :inet.parse_address()
              |> elem(1)
          }
        )
      )
    )
  end

  def parse_type(["CNAME", cname], left, current, zone) do
    parse_zone(
      left,
      %{host: current.host},
      add_rdata(
        zone,
        current
        |> Map.put(:type, :cname)
        |> Map.put(:rdata, %{name: get_fqdn(cname, zone.origin)})
      )
    )
  end

  def parse_type(["MX", pref, exchange], left, current, zone) do
    parse_zone(
      left,
      %{host: current.host},
      add_rdata(
        zone,
        current
        |> Map.put(:type, :mx)
        |> Map.put(:rdata, %{
          preference: String.to_integer(pref),
          name: get_fqdn(exchange, zone.origin)
        })
      )
    )
  end

  @spec add_rdata(
          map,
          %{host: String, class: atom, type: atom, rdata: list, ttl: integer}
        ) :: map
  def add_rdata(zone, current) do
    rdata = Map.put(current.rdata, :ttl, current.ttl)

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
                Enum.reverse([rdata | Enum.reverse(type_record)])
              end
            )
          end
        )
      end
    )
  end
end
