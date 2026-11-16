defmodule QuickSlipsWeb.Plugs.RateLimitTest do
  # Not async: the tests set the rules, which belong to the whole application.
  use ExUnit.Case, async: false

  import Plug.Conn, only: [get_resp_header: 2]
  import Plug.Test
  import QuickSlips.RateLimitHelpers

  alias QuickSlipsWeb.Plugs.RateLimit

  defp call(ip, name \\ :generate) do
    :post
    |> conn("/api/generate")
    |> Map.put(:remote_ip, ip)
    |> RateLimit.call(RateLimit.init(name: name))
  end

  test "lets an address through up to the limit, then answers 429 with the time to wait" do
    put_limit(:generate, 2, 60)
    ip = unique_ip()

    refute call(ip).halted
    refute call(ip).halted

    conn = call(ip)
    assert conn.halted
    assert conn.status == 429
    assert %{"code" => "slow_down", "error" => _} = Jason.decode!(conn.resp_body)
    assert [seconds] = get_resp_header(conn, "retry-after")
    assert String.to_integer(seconds) in 1..60
  end

  test "another address is not slowed down by the first" do
    put_limit(:generate, 1, 60)
    one = unique_ip()
    other = unique_ip()

    refute call(one).halted
    assert call(one).halted
    refute call(other).halted
  end

  test "every address of one IPv6 /64 is one address" do
    put_limit(:generate, 1, 60)
    n = System.unique_integer([:positive])

    # A group of an IPv6 address has 16 bits and the counter of a test run can have more (it counts for every test,
    # and a long run goes past 65535), so the number is spread over two groups of the /64.
    {high, low} = {rem(div(n, 65_536), 65_536), rem(n, 65_536)}

    refute call({0x2001, 0x0DB8, high, low, 0, 0, 0, 1}).halted
    assert call({0x2001, 0x0DB8, high, low, 0x1111, 0x2222, 0x3333, 0x4444}).halted
  end

  test "each rule counts for itself" do
    put_limit(:generate, 1, 60)
    put_limit(:api, 1, 60)
    ip = unique_ip()

    refute call(ip, :generate).halted
    refute call(ip, :api).halted
    assert call(ip, :generate).halted
  end
end
