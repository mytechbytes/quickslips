defmodule QuickSlipsWeb.LocaleController do
  @moduledoc """
  The language and country switch (`QuickSlipsWeb.UI.locale_menu/1`) posts here with the locale the visitor chose
  and the page they are on (`from`). The choice is kept in the session, for the pages of this visit, and in the
  cookie `qs_locale`, for the next visits; then the visitor goes to the same page in the new locale.

  The cookie is set only here, in answer to a click: it is the visitor's own preference, not something a page
  visit does behind their back.

  The page's script (`assets/js/locale.ts`) posts with the header `x-locale-switch: fetch` and gets JSON back
  (`%{to: path, live: bool, lang: "hi-IN"}`) instead of a redirect, so that it can move on by a live navigation
  where that is possible: the catalogue of a locale and a bill are LiveViews, and going from one to another needs
  no new page. A page without a locale in its address, and a page that is not in the new language (which carries
  a flash), is a full load.
  """
  use QuickSlipsWeb, :controller

  alias QuickSlips.Locales
  alias QuickSlipsWeb.LocaleSwitch
  alias QuickSlipsWeb.Plugs.Locale, as: LocalePlug

  @one_year 60 * 60 * 24 * 365

  def update(conn, %{"locale" => code} = params) do
    from = from(conn, params)

    case Locales.fetch(code) do
      {:ok, locale} ->
        {path, found} = LocaleSwitch.target(from, locale)

        conn =
          conn
          |> put_session(:locale, locale.code)
          |> put_resp_cookie(LocalePlug.cookie_name(), locale.code,
            max_age: @one_year,
            http_only: true,
            same_site: "Lax",
            secure: conn.scheme == :https
          )
          |> tell_if_unavailable(found, locale)

        if "fetch" in get_req_header(conn, "x-locale-switch") do
          json(conn, %{
            to: path,
            live: found == :same and locale_pages?(from, path),
            lang: Locales.hreflang(locale)
          })
        else
          redirect(conn, to: path)
        end

      :error ->
        redirect(conn, to: from)
    end
  end

  def update(conn, _params), do: redirect(conn, to: ~p"/")

  # A live navigation is for one page that has its locale in the address to another (`/en-in` to `/hi-in`, a bill
  # to the same bill): both are LiveViews of the same live session, and the locale is in the address, so the
  # session cookie does not matter.
  defp locale_pages?(from, path), do: locale_page?(URI.parse(from).path) and locale_page?(path)

  defp locale_page?(path),
    do: is_binary(path) and Regex.match?(~r/^\/[a-z]{2}-[a-z]{2}(\/[a-z0-9-]+)?$/, path)

  # The page the visitor was on is not in the language they chose: say so, in that language.
  defp tell_if_unavailable(conn, :same, _locale), do: conn

  defp tell_if_unavailable(conn, :unavailable, locale) do
    message =
      Gettext.with_locale(QuickSlipsWeb.Gettext, locale.language, fn ->
        gettext(
          "This page is not available in this language yet. Here are the templates that are."
        )
      end)

    put_flash(conn, :info, message)
  end

  # The form fills `from` in with the page's address when it is submitted. Without scripts it is empty, and the
  # `Referer` says where the visitor came from.
  defp from(conn, params) do
    LocaleSwitch.safe_path(params["from"]) || referer_path(conn) || "/"
  end

  defp referer_path(conn) do
    with [referer | _] <- get_req_header(conn, "referer"),
         %URI{host: host, path: path, query: query} when host == conn.host and is_binary(path) <-
           URI.parse(referer) do
      LocaleSwitch.safe_path(path <> if(query, do: "?" <> query, else: ""))
    else
      _ -> nil
    end
  end
end
