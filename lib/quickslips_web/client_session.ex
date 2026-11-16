defmodule QuickSlipsWeb.ClientSession do
  @moduledoc """
  What a LiveView needs to know about the visitor and can no longer see once it is connected.

  Behind the proxy the peer of the socket is the proxy, not the visitor: only the first request, the one that loads the
  page, knows the visitor's real address (`QuickSlipsWeb.Plugs.CloudflareIp` has put it in `conn.remote_ip`). The
  `live_session` of the router calls `session/1` with that request and keeps the answer in the signed session of the
  LiveView, which the visitor can read but not change.

  The address is kept as the key the counters use (`QuickSlips.ClientIp.key/1`), not as an address. A LiveView reads it with
  `client_ip/1`.
  """
  alias QuickSlips.ClientIp

  @key "client_ip"

  @doc "The part of the LiveView session that comes from the request (the `session:` of a `live_session`)."
  def session(conn), do: %{@key => ClientIp.key(conn.remote_ip)}

  @doc "The counter key of the visitor's address, from the session a LiveView was given (`\"unknown\"` if it has none)."
  def client_ip(%{@key => key}) when is_binary(key), do: key
  def client_ip(_session), do: "unknown"
end
