defmodule QuickSlipsWeb.Plugs.Locale do
  @moduledoc """
  Decides in which locale (language and country) a page is shown, and tells everything that needs to know:
  the `locale` assign, the language of Gettext for this request, and the session.

  Where the locale comes from, first that applies:

    1. the first segment of the address, on the routes `/:locale` (the catalogue) and `/:locale/:slug` (a bill).
       Only a path segment counts: a `?locale=` in the query is just a query. A segment that is not a live locale
       is an old address, which was one segment (the whole address of a template used to be `/fuel-bill`) and
       moves permanently to its new page, or nothing: a 404;
    2. what the session remembers: the locale of the last page the visitor saw;
    3. the cookie `qs_locale`, which `QuickSlipsWeb.LocaleController` sets when the visitor chooses a language;
    4. a guess from the browser's language and country (`QuickSlips.Locales.guess/3`).

  Pages that have no locale in their address (the log-in page, the dashboard) use 2 to 4, so they speak the
  language of the page the visitor came from. The session is the cookie every visitor already has, so remembering
  there asks for nothing new; only an explicit choice makes the longer-lived cookie.

  LiveViews run in their own process, which `on_mount/4` gives the same language.
  """
  import Plug.Conn
  import Phoenix.Controller, only: [redirect: 2]

  alias QuickSlips.Locales
  alias QuickSlips.Templates
  alias QuickSlipsWeb.Seo

  @cookie "qs_locale"

  @doc "The name of the cookie that holds a visitor's own choice."
  def cookie_name, do: @cookie

  def init(opts), do: opts

  def call(conn, _opts) do
    conn = fetch_cookies(conn)

    case conn.path_params do
      %{"locale" => code} -> from_address(conn, code)
      _no_locale_in_the_address -> use_locale(conn, remembered(conn))
    end
  end

  @doc """
  The locale of a visitor whose address says none: what the session remembers, then their cookie, then a guess.
  """
  def remembered(conn) do
    live_locale(get_session(conn, :locale)) || live_locale(conn.cookies[@cookie]) ||
      Locales.guess(header(conn, "accept-language"), header(conn, "cf-ipcountry"))
  end

  @doc """
  `on_mount` for LiveViews: the language of Gettext and the `locale` assign, from the session (the plug has put
  the locale of this request in it). Put it first in the list, so the hooks after it speak the language too.
  """
  def on_mount(:default, _params, session, socket) do
    locale = live_locale(session["locale"]) || Locales.default()
    Gettext.put_locale(QuickSlipsWeb.Gettext, locale.language)

    {:cont, Phoenix.Component.assign(socket, :locale, locale)}
  end

  defp from_address(conn, code) do
    case Locales.fetch(code) do
      {:ok, locale} ->
        conn = use_locale(conn, locale)
        if conn.path_params["slug"], do: conn, else: merge_assigns(conn, Seo.home(locale))

      :error ->
        moved_or_missing(conn, code)
    end
  end

  defp use_locale(conn, locale) do
    Gettext.put_locale(QuickSlipsWeb.Gettext, locale.language)

    conn
    |> assign(:locale, locale)
    |> remember(locale)
  end

  # Only writes when something changed, so a page the visitor keeps reloading sends no new cookie.
  defp remember(conn, locale) do
    if get_session(conn, :locale) == locale.code,
      do: conn,
      else: put_session(conn, :locale, locale.code)
  end

  defp live_locale(code) do
    case Locales.fetch(code) do
      {:ok, locale} -> locale
      :error -> nil
    end
  end

  defp header(conn, name), do: conn |> get_req_header(name) |> List.first()

  defp moved_or_missing(%Plug.Conn{path_params: %{"slug" => _}}, _code),
    do: raise(QuickSlipsWeb.NotFoundError)

  defp moved_or_missing(conn, old_slug) do
    case Templates.legacy_target(old_slug) do
      {:ok, locale_code, public_slug} ->
        query = if conn.query_string == "", do: "", else: "?" <> conn.query_string

        conn
        |> put_status(:moved_permanently)
        |> redirect(to: "/#{locale_code}/#{public_slug}" <> query)
        |> halt()

      :error ->
        raise QuickSlipsWeb.NotFoundError
    end
  end
end
