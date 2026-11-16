defmodule QuickSlipsWeb.Plugs.ContentSecurityPolicy do
  @moduledoc """
  Puts the Content-Security-Policy (`QuickSlipsWeb.ContentSecurityPolicy`) on the pages, with a nonce of its own for each
  response, which it also gives to the layouts as `@csp_nonce` (`nonce={assigns[:csp_nonce]}` on a script tag that is part
  of the page).

  It goes after `put_secure_browser_headers`, whose own policy (`base-uri` and `frame-ancestors`, nothing about scripts) it
  replaces where it is enforced: the new one has both and a lot more.
  """
  import Plug.Conn

  alias QuickSlipsWeb.ContentSecurityPolicy

  def init(options), do: options

  def call(conn, _options) do
    mode = ContentSecurityPolicy.mode()
    nonce = nonce()
    conn = assign(conn, :csp_nonce, nonce)

    case ContentSecurityPolicy.header_name(mode) do
      nil ->
        conn

      header ->
        put_resp_header(drop_short_policy(conn, mode), header, ContentSecurityPolicy.build(nonce))
    end
  end

  # `put_secure_browser_headers` has put its own policy. Where ours is enforced it is dropped (ours says the same and
  # more); where ours only reports, or is off, it stays, so that those two things are still kept.
  defp drop_short_policy(conn, :enforce), do: delete_resp_header(conn, "content-security-policy")
  defp drop_short_policy(conn, _other), do: conn

  # 128 bits from the system's random source: nobody can guess the one of the next response.
  defp nonce, do: 16 |> :crypto.strong_rand_bytes() |> Base.encode64()
end
