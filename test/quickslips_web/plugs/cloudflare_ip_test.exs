defmodule QuickSlipsWeb.Plugs.CloudflareIpTest do
  # Not async: the tests change the application environment.
  use ExUnit.Case, async: false

  import Plug.Conn
  import Plug.Test

  alias QuickSlipsWeb.Plugs.CloudflareIp

  @proxy {172, 18, 0, 5}

  setup do
    on_exit(fn -> Application.delete_env(:quickslips, :trust_cloudflare_ip) end)
  end

  defp request(header, trust?) do
    Application.put_env(:quickslips, :trust_cloudflare_ip, trust?)

    :get
    |> conn("/")
    |> Map.put(:remote_ip, @proxy)
    |> put_req_header("cf-connecting-ip", header)
    |> CloudflareIp.call([])
  end

  test "uses the address Cloudflare reports when the flag is on" do
    assert request("203.0.113.9", true).remote_ip == {203, 0, 113, 9}
    assert request("2001:db8::1", true).remote_ip == {0x2001, 0x0DB8, 0, 0, 0, 0, 0, 1}
  end

  test "ignores the header when the flag is off" do
    assert request("203.0.113.9", false).remote_ip == @proxy
  end

  test "ignores a header that is not an IP address" do
    assert request("not-an-ip", true).remote_ip == @proxy
  end

  test "does nothing without the header" do
    Application.put_env(:quickslips, :trust_cloudflare_ip, true)

    result =
      :get
      |> conn("/")
      |> Map.put(:remote_ip, @proxy)
      |> CloudflareIp.call([])

    assert result.remote_ip == @proxy
  end
end
