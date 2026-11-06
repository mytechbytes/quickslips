defmodule QuickSlipsWeb.Plugs.LocaleTest do
  use QuickSlipsWeb.ConnCase

  import Phoenix.LiveViewTest

  # The text of the first `<h1>` of a page, and its `lang`.
  defp h1(html), do: html |> LazyHTML.from_document() |> LazyHTML.query("h1") |> LazyHTML.text()

  defp lang(html),
    do: html |> LazyHTML.from_document() |> LazyHTML.query("html") |> LazyHTML.attribute("lang")

  describe "a page that has no locale in its address" do
    test "speaks English, for India, to a visitor who has said nothing", %{conn: conn} do
      html = conn |> get(~p"/users/log-in") |> html_response(200)

      assert lang(html) == ["en-IN"]
      assert h1(html) =~ "Log in to QuickSlips"
    end

    test "speaks the language of the last page the visitor saw", %{conn: conn} do
      conn = get(conn, ~p"/hi-in")
      assert get_session(conn, :locale) == "hi-in"

      html = conn |> recycle() |> get(~p"/users/log-in") |> html_response(200)

      assert lang(html) == ["hi-IN"]
      assert h1(html) =~ "QuickSlips में लॉग इन करें"
    end

    test "the address of a page beats what the session remembers", %{conn: conn} do
      conn = get(conn, ~p"/hi-in")
      conn = conn |> recycle() |> get(~p"/es-es")

      assert get_session(conn, :locale) == "es-es"
      assert h1(html_response(conn, 200)) =~ "Facturas y recibos, listos en segundos"
    end

    test "uses the cookie of a visitor who chose a language, when the session knows nothing", %{
      conn: conn
    } do
      html =
        conn
        |> put_req_cookie("qs_locale", "es-es")
        |> get(~p"/users/log-in")
        |> html_response(200)

      assert lang(html) == ["es-ES"]
      assert h1(html) =~ "Inicia sesión en QuickSlips"
    end

    test "the session is more recent than the cookie", %{conn: conn} do
      conn = get(conn, ~p"/hi-in")

      html =
        conn
        |> recycle()
        |> put_req_cookie("qs_locale", "es-es")
        |> get(~p"/users/log-in")
        |> html_response(200)

      assert lang(html) == ["hi-IN"]
    end

    test "ignores a cookie that names no live locale", %{conn: conn} do
      for value <- ["es-mx", "xx-yy", "", "<script>"] do
        html =
          conn
          |> put_req_cookie("qs_locale", value)
          |> get(~p"/users/log-in")
          |> html_response(200)

        assert lang(html) == ["en-IN"]
      end
    end

    test "does not offer Hindi or Spanish to a browser that asks for it, while they are small", %{
      conn: conn
    } do
      html =
        conn
        |> put_req_header("accept-language", "hi-IN,hi;q=0.9")
        |> get(~p"/users/log-in")
        |> html_response(200)

      assert lang(html) == ["en-IN"]
    end

    test "does not write the session again for a page the visitor keeps reloading", %{conn: conn} do
      conn = get(conn, ~p"/hi-in")
      assert Map.has_key?(conn.resp_cookies, "_quickslips_key")

      reloaded = conn |> recycle() |> get(~p"/hi-in")

      refute Map.has_key?(reloaded.resp_cookies, "_quickslips_key")
    end
  end

  describe "a query is not an address" do
    test "?locale= on a page that has no locale in its address is only a query", %{conn: conn} do
      for query <- ["locale=zzz", "locale=hi-in", "locale=", "locale[]=x"] do
        html = conn |> get("/users/log-in?#{query}") |> html_response(200)

        assert lang(html) == ["en-IN"], "?#{query} changed the page"
      end

      assert conn |> get("/healthz?locale=zzz") |> response(200)
    end

    test "or on the page of a locale, where the address says which one", %{conn: conn} do
      conn = get(conn, "/hi-in?locale=es-es")

      assert lang(html_response(conn, 200)) == ["hi-IN"]
    end
  end

  describe "Gettext" do
    test "speaks the language of the page during the request", %{conn: conn} do
      for {path, text} <- [
            {"/hi-in", "लॉग इन"},
            {"/es-es", "Iniciar sesión"},
            {"/en-in", "Log in"}
          ] do
        assert conn |> get(path) |> html_response(200) =~ text
      end
    end

    test "is set for a LiveView too, from the session", %{conn: conn} do
      conn = get(conn, ~p"/es-es")

      {:ok, view, _html} = conn |> recycle() |> live(~p"/users/log-in")

      assert render(view) =~ "Inicia sesión en QuickSlips"
      assert render(view) =~ ~s(lang="es")
    end

    test "a catalogue speaks the language of its address, whatever the session says", %{
      conn: conn
    } do
      conn = get(conn, ~p"/es-es")

      {:ok, view, html} = conn |> recycle() |> live(~p"/hi-in")

      assert html =~ "बिल और रसीदें, कुछ ही सेकंड में तैयार"
      assert render(view) =~ "लॉग इन"
    end
  end
end
