defmodule QuickSlips.ClientIp do
  @moduledoc """
  The address of a visitor as the *key* of a counter (the free downloads of the day, the rate limits).

  One IPv4 address is one visitor (or one household behind a router). One IPv6 address is not: a home or a phone is
  given a whole /64 (2^64 addresses) and may use any of them, so a counter per full address would never fill up and
  would be no limit at all. The key of an IPv6 address is therefore its /64 prefix. An IPv4-mapped IPv6 address
  (`::ffff:203.0.113.9`) is the IPv4 address it carries.

  The key is for counting. What is sent to somebody else (Cloudflare Turnstile asks for the visitor's address) stays
  the full address.
  """

  import Bitwise

  @doc """
  The counter key of an address, given as a tuple (`conn.remote_ip`) or as text (`"2001:db8::1"`).

      iex> QuickSlips.ClientIp.key({203, 0, 113, 9})
      "203.0.113.9"

      iex> QuickSlips.ClientIp.key({0x2001, 0x0DB8, 1, 2, 3, 4, 5, 6})
      "2001:db8:1:2::/64"
  """
  def key({_, _, _, _} = ipv4), do: ipv4 |> :inet.ntoa() |> to_string()

  # ::ffff:a.b.c.d is an IPv4 address that arrived over an IPv6 socket.
  def key({0, 0, 0, 0, 0, 0xFFFF, high, low}),
    do: key({high >>> 8, high &&& 0xFF, low >>> 8, low &&& 0xFF})

  def key({a, b, c, d, _, _, _, _}),
    do: "#{[a, b, c, d, 0, 0, 0, 0] |> List.to_tuple() |> :inet.ntoa()}/64"

  def key(text) when is_binary(text) do
    case text |> String.to_charlist() |> :inet.parse_address() do
      {:ok, address} -> key(address)
      {:error, _not_an_address} -> text
    end
  end

  def key(_none), do: "unknown"
end
