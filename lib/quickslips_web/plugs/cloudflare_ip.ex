defmodule QuickSlipsWeb.Plugs.CloudflareIp do
  @moduledoc """
  Sets `conn.remote_ip` from Cloudflare's `CF-Connecting-IP` header.
  Does nothing unless `config :quickslips, :trust_cloudflare_ip, true`.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    with true <- Application.get_env(:quickslips, :trust_cloudflare_ip, false),
         [value] <- get_req_header(conn, "cf-connecting-ip"),
         {:ok, ip} <- :inet.parse_address(String.to_charlist(value)) do
      %{conn | remote_ip: ip}
    else
      _ -> conn
    end
  end
end
