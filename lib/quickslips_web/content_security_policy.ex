defmodule QuickSlipsWeb.ContentSecurityPolicy do
  @moduledoc """
  The Content-Security-Policy of the pages: a list, for each kind of thing a page loads, of where it may come from. A
  browser that finds something outside the list does not load it. If a script is ever put into a page by somebody who
  should not be able to (a missing escape, a bad dependency), the browser still refuses to run it.

  `build/1` makes the header for one response. What a page of the site loads, and so what is allowed:

    * **Scripts**: the bundle (`'self'`), the one small script of the root layout that sets the theme before the page is
      drawn (it has the `nonce` of the response: a random value that goes into the header and into the tag, and is
      new for each response, so a script that somebody else put into the page cannot have it), Cloudflare Turnstile,
      Google Tag Manager, and `'wasm-unsafe-eval'` so that the preview can start the Typst compiler (WebAssembly in
      the browser; it does not allow `eval` of text).
    * **Cloudflare's own script** that it adds to the pages that pass through it (bot detection) is an inline script.
      Cloudflare reads the nonce of the header and puts it on that script, which is why the nonce is there for it too.
    * **Styles**: the stylesheet, and inline `style` attributes (Tailwind and the components set a few).
    * **Pictures**: the site, `data:` (the icons are CSS masks), `blob:` (the preview is drawn from pictures made in
      the browser) and what Google Analytics asks for.
    * **Connections** (`fetch`, the LiveView socket): the site and its own socket, Turnstile and Google Analytics.
    * **Frames**: Turnstile (its widget), and Google's Tag Assistant (the preview of a Tag Manager container).

  Nothing may be put in `<object>`, `<embed>` (`object-src 'none'`), and a page can neither be framed by another site
  nor send a form to one (`frame-ancestors`, `form-action`). `base-uri` stops a `<base>` tag that would send every
  relative address somewhere else.

  `config :quickslips, :csp` says what is done with it: `:enforce` (the browser refuses what is outside), `:report_only`
  (the browser only says so in its console: for trying a change, and the default of the development machine) or `:off`.
  The environment variable `CSP_MODE` sets it at start, so a policy that is in the way of something can be turned down
  to `report_only` without a new version of the code.
  """

  @turnstile "https://challenges.cloudflare.com"
  @tag_manager "https://www.googletagmanager.com"
  @tag_assistant "https://tagassistant.google.com"

  # What Google Analytics 4 sends its measurements to (as a request, or as a one-pixel picture).
  @analytics ~w(https://*.google-analytics.com https://*.analytics.google.com https://*.googletagmanager.com)

  @doc "What is done with the policy: `:enforce`, `:report_only` or `:off`."
  def mode, do: Application.get_env(:quickslips, :csp, :enforce)

  @doc "The name of the header for the mode, or `nil` for `:off`."
  def header_name(:enforce), do: "content-security-policy"
  def header_name(:report_only), do: "content-security-policy-report-only"
  def header_name(:off), do: nil

  @doc """
  The value of the header for a response whose scripts carry `nonce`. `site_url` is the address of the site (the
  endpoint's own, `https://quickslips.example` in production), from which the address of the LiveView socket is made.
  """
  def build(nonce, site_url \\ QuickSlipsWeb.Endpoint.url()) do
    site = URI.parse(site_url)

    [
      {"default-src", ["'self'"]},
      {"script-src",
       ["'self'", "'nonce-#{nonce}'", "'wasm-unsafe-eval'", @turnstile, @tag_manager]},
      {"style-src", ["'self'", "'unsafe-inline'"]},
      {"img-src", ["'self'", "data:", "blob:" | @analytics]},
      {"font-src", ["'self'"]},
      {"connect-src", ["'self'", socket_origin(site), @turnstile | @analytics]},
      {"frame-src", ["'self'", @turnstile, @tag_assistant]},
      {"worker-src", ["'self'"]},
      {"manifest-src", ["'self'"]},
      {"object-src", ["'none'"]},
      {"base-uri", ["'self'"]},
      {"form-action", ["'self'"]},
      {"frame-ancestors", ["'self'"]}
    ]
    |> Kernel.++(upgrade_insecure_requests(site))
    |> Enum.map_join("; ", fn {directive, sources} -> Enum.join([directive | sources], " ") end)
  end

  # The LiveView socket is a WebSocket to the site itself. `'self'` covers it in current browsers, and some older ones
  # (Safari before 15.4) do not take `'self'` for `ws:`, so the address is also given in full.
  defp socket_origin(%URI{scheme: scheme, host: host, port: port}) do
    {socket_scheme, default_port} = if scheme == "https", do: {"wss", 443}, else: {"ws", 80}
    "#{socket_scheme}://#{host}#{if port in [nil, default_port], do: "", else: ":#{port}"}"
  end

  # In production every address is https: a picture or script that is asked for over http is asked for over https.
  defp upgrade_insecure_requests(%URI{scheme: "https"}), do: [{"upgrade-insecure-requests", []}]
  defp upgrade_insecure_requests(_site), do: []
end
