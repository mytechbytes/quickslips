defmodule QuickSlips.ClientIpTest do
  use ExUnit.Case, async: true

  alias QuickSlips.ClientIp

  doctest QuickSlips.ClientIp

  test "an IPv4 address is its own key, as a tuple or as text" do
    assert ClientIp.key({203, 0, 113, 9}) == "203.0.113.9"
    assert ClientIp.key("203.0.113.9") == "203.0.113.9"
  end

  test "an IPv6 address is counted by its /64: the 2^64 addresses of one home are one visitor" do
    one = {0x2001, 0x0DB8, 0x00AA, 0x0001, 0, 0, 0, 1}
    another = {0x2001, 0x0DB8, 0x00AA, 0x0001, 0xDEAD, 0xBEEF, 0x1234, 0x5678}
    next_home = {0x2001, 0x0DB8, 0x00AA, 0x0002, 0, 0, 0, 1}

    assert ClientIp.key(one) == "2001:db8:aa:1::/64"
    assert ClientIp.key(another) == ClientIp.key(one)
    refute ClientIp.key(next_home) == ClientIp.key(one)
  end

  test "an IPv6 address in its written form has the same key as its tuple" do
    assert ClientIp.key("2001:db8:aa:1:dead:beef:1234:5678") ==
             ClientIp.key({0x2001, 0x0DB8, 0x00AA, 0x0001, 0xDEAD, 0xBEEF, 0x1234, 0x5678})
  end

  test "an IPv4 address that came over an IPv6 socket is the IPv4 address" do
    assert ClientIp.key({0, 0, 0, 0, 0, 0xFFFF, 0xCB00, 0x7109}) == "203.0.113.9"
    assert ClientIp.key("::ffff:203.0.113.9") == "203.0.113.9"
  end

  test "what is no address is kept as it is, and nothing is a placeholder" do
    assert ClientIp.key("not-an-ip") == "not-an-ip"
    assert ClientIp.key(nil) == "unknown"
  end
end
