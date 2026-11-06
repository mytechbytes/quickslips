defmodule QuickSlipsWeb.RootController do
  @moduledoc """
  `/` has no page of its own: it sends the visitor to the home page of the locale they are most likely to want:
  the one they chose, or the one of the last page they saw, or a guess (see `QuickSlipsWeb.Plugs.Locale`). The
  answer depends on who asks, so nobody may keep it.
  """
  use QuickSlipsWeb, :controller

  alias QuickSlips.Locales

  def index(conn, _params) do
    locale = conn.assigns.locale
    query = if conn.query_string == "", do: "", else: "?" <> conn.query_string

    conn
    |> put_resp_header("cache-control", "private, no-store")
    |> redirect(to: Locales.path(locale) <> query)
  end
end
