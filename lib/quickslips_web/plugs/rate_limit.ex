defmodule QuickSlipsWeb.Plugs.RateLimit do
  @moduledoc """
  Says "slow down" to an address that asks too often: `plug QuickSlipsWeb.Plugs.RateLimit, name: :generate`.

  `name` is one of the rules of `QuickSlips.RateLimit`, which has its limit. The count is per visitor address
  (`QuickSlips.ClientIp`: an IPv6 address counts by its /64), which is `conn.remote_ip` after `Plugs.CloudflareIp` has
  put the real address there.

  Over the limit the answer is `429` with a `retry-after` header (seconds) and `{"error": ..., "code": "slow_down"}`,
  and the request goes no further. The `code` tells it from the other 429 of the site, which means "the day's free
  downloads are used" (`daily limit reached`).

  Put it first in a pipeline, so a flood is turned away before the session, the database or anything else is touched.
  """
  import Plug.Conn

  alias QuickSlips.ClientIp
  alias QuickSlips.RateLimit

  def init(options), do: Keyword.fetch!(options, :name)

  def call(conn, name) do
    case RateLimit.hit(name, ClientIp.key(conn.remote_ip)) do
      :ok ->
        conn

      {:error, seconds} ->
        conn
        |> put_resp_header("retry-after", Integer.to_string(seconds))
        |> put_status(:too_many_requests)
        |> Phoenix.Controller.json(%{error: "too many requests, slow down", code: "slow_down"})
        |> halt()
    end
  end
end
