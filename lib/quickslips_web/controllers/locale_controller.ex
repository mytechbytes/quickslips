defmodule QuickSlipsWeb.LocaleController do
  @moduledoc """
  The language and country switch (`QuickSlipsWeb.UI.locale_menu/1`) posts here with the locale the visitor chose
  and the page they are on (`from`). The choice is kept in the session, for the pages of this visit, and in the
  cookie `qs_locale`, for the next visits; then the visitor goes to the same page in the new locale.

  The cookie is set only here, in answer to a click: it is the visitor's own preference, not something a page
  visit does behind their back.
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

        conn
        |> put_session(:locale, locale.code)
        |> put_resp_cookie(LocalePlug.cookie_name(), locale.code,
          max_age: @one_year,
          http_only: true,
          same_site: "Lax",
          secure: conn.scheme == :https
        )
        |> tell_if_unavailable(found, locale)
        |> redirect(to: path)

      :error ->
        redirect(conn, to: from)
    end
  end

  def update(conn, _params), do: redirect(conn, to: ~p"/")

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
