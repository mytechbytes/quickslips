defmodule QuickSlipsWeb.RootControllerTest do
  use QuickSlipsWeb.ConnCase

  test "/ leads to the catalogue of the default locale", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert redirected_to(conn) == "/en-in"
  end

  test "nobody may keep the answer, since it depends on who asks", %{conn: conn} do
    conn = get(conn, ~p"/")

    assert get_resp_header(conn, "cache-control") == ["private, no-store"]
  end

  test "keeps the query", %{conn: conn} do
    conn = get(conn, "/?utm_source=newsletter")

    assert redirected_to(conn) == "/en-in?utm_source=newsletter"
  end

  # Hindi and Spanish are live, but small: nobody is sent there until their catalogues are as big as the English one.
  test "does not offer a locale that is not marked for it, whatever the browser asks for", %{
    conn: conn
  } do
    for language <- ["hi-IN,hi;q=0.9", "es-ES,es;q=0.9", "fr-FR"] do
      conn = conn |> put_req_header("accept-language", language) |> get(~p"/")

      assert redirected_to(conn) == "/en-in"
    end
  end

  test "reads the country Cloudflare adds without failing on what it can't use", %{conn: conn} do
    for country <- ["ES", "IN", "XX", "T1", ""] do
      conn = conn |> put_req_header("cf-ipcountry", country) |> get(~p"/")

      assert redirected_to(conn) == "/en-in"
    end
  end
end
