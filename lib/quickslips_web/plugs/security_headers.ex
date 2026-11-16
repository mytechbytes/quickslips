defmodule QuickSlipsWeb.Plugs.SecurityHeaders do
  @moduledoc """
  The headers that every response has, whatever answers it (a page, the JSON of the API, a PDF, a file of `priv/static`).
  It sits at the top of the endpoint, before the static files; a route that is in the `:browser` pipeline adds the
  page's own (`put_secure_browser_headers`, and the Content-Security-Policy of `Plugs.ContentSecurityPolicy`).

    * `x-content-type-options: nosniff`: a browser takes a file for what its `content-type` says, never for what it looks
      like (a picture that has a script in it is not run as a script).
    * `x-frame-options: SAMEORIGIN`: no other site may put a page of ours in a frame. The `frame-ancestors` of the policy says
      the same; this is for the browsers that do not read it.
    * `referrer-policy: strict-origin-when-cross-origin`: another site that is linked to gets the address of the
      site, not the page, and nothing at all from a page that is `http`.
    * `permissions-policy`: the browser features that the site does not use are off, for the page and for every frame
      in it, so that a script that is somewhere it should not be cannot ask for the camera or the position.
    * `cross-origin-opener-policy`: a page that another site opens in a window (or that opens one) is cut off from it,
      so that the other site cannot reach into the page's window. `config :quickslips, :cross_origin_opener_policy`
      sets it (`"same-origin"` by default; `nil` or `"off"` leaves the header out), and the environment variable
      `CROSS_ORIGIN_OPENER_POLICY` sets it at start. *Google's Tag Assistant (the preview of Tag Manager) opens the site
      in a window of its own and talks to it, and a policy other than `unsafe-none` cuts that off: while a container is
      tried, set the variable to `unsafe-none`.*

  `strict-transport-security` is not here: `force_ssl` in `config/prod.exs` makes `Plug.SSL` send it for every response
  (a year, `max-age=31536000`).
  """
  import Plug.Conn

  @permissions_policy "camera=(), microphone=(), geolocation=(), usb=(), gyroscope=(), accelerometer=(), magnetometer=()"

  def init(options), do: options

  def call(conn, _options) do
    conn
    |> put_resp_header("x-content-type-options", "nosniff")
    |> put_resp_header("x-frame-options", "SAMEORIGIN")
    |> put_resp_header("referrer-policy", "strict-origin-when-cross-origin")
    |> put_resp_header("permissions-policy", @permissions_policy)
    |> put_opener_policy()
  end

  defp put_opener_policy(conn) do
    case Application.get_env(:quickslips, :cross_origin_opener_policy, "same-origin") do
      value when value in [nil, "", "off"] -> conn
      value -> put_resp_header(conn, "cross-origin-opener-policy", value)
    end
  end
end
