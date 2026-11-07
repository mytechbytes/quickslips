defmodule QuickSlipsWeb.LocaleControllerTest do
  use QuickSlipsWeb.ConnCase

  defp choose(conn, locale, from),
    do: post(conn, ~p"/locale", %{"locale" => locale, "from" => from})

  describe "choosing a locale" do
    test "goes to the same bill in the new locale", %{conn: conn} do
      conn = choose(conn, "hi-in", "/en-in/fuel-bill-generator")

      assert redirected_to(conn) == "/hi-in/fuel-bill-generator"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) == nil
    end

    test "remembers the choice for this visit, in the session", %{conn: conn} do
      conn = choose(conn, "es-es", "/en-in")

      assert get_session(conn, :locale) == "es-es"
    end

    test "and for the next visits, in a cookie that only the server reads", %{conn: conn} do
      conn = choose(conn, "hi-in", "/en-in")

      assert %{value: "hi-in", max_age: 31_536_000, http_only: true, same_site: "Lax"} =
               conn.resp_cookies["qs_locale"]
    end

    test "the next visit starts in the chosen locale, even one that is not offered to guessers",
         %{conn: conn} do
      conn = choose(conn, "hi-in", "/en-in")

      # this visit: the session
      assert conn |> recycle() |> get(~p"/") |> redirected_to() == "/hi-in"
      # a visit later, with the cookie and without the session
      assert build_conn() |> put_req_cookie("qs_locale", "hi-in") |> get(~p"/") |> redirected_to() ==
               "/hi-in"
    end

    test "pages with no locale in their address follow the choice", %{conn: conn} do
      conn = choose(conn, "es-es", "/users/log-in")

      assert redirected_to(conn) == "/users/log-in"

      html = conn |> recycle() |> get(~p"/users/log-in") |> html_response(200)
      assert html =~ "Inicia sesión en QuickSlips"
    end

    test "a bill that the new locale has not got goes to its catalogue, with the reason in that language",
         %{
           conn: conn
         } do
      conn = choose(conn, "hi-in", "/en-in/courier-receipt-generator")

      assert redirected_to(conn) == "/hi-in"

      assert Phoenix.Flash.get(conn.assigns.flash, :info) ==
               "यह पेज अभी इस भाषा में उपलब्ध नहीं है। जो टेम्पलेट उपलब्ध हैं, वे यहाँ हैं।"
    end

    test "keeps the query of the page", %{conn: conn} do
      conn = choose(conn, "es-es", "/en-in/fuel-bill-generator?from=7")

      assert redirected_to(conn) == "/es-es/generador-de-factura-de-gasolina?from=7"
    end
  end

  describe "what it refuses" do
    test "a place that is not on this site", %{conn: conn} do
      for from <- [
            "//evil.example",
            "https://evil.example/",
            "/\\evil.example",
            "javascript:alert(1)"
          ] do
        conn = choose(conn, "hi-in", from)

        assert redirected_to(conn) == "/", "#{from} was followed"
      end
    end

    test "a locale that is not live, or that does not exist: nothing is remembered", %{conn: conn} do
      for locale <- ["es-mx", "xx-yy", "", "EN-IN", "<script>"] do
        conn = choose(conn, locale, "/users/log-in")

        assert redirected_to(conn) == "/users/log-in"
        # The session holds what the visitor had (the default here), and no cookie is made.
        assert get_session(conn, :locale) == "en-in"
        refute Map.has_key?(conn.resp_cookies, "qs_locale")
      end
    end

    test "a request with no locale at all", %{conn: conn} do
      assert conn |> post(~p"/locale", %{}) |> redirected_to() == "/"
      assert conn |> post(~p"/locale", %{"from" => "/en-in"}) |> redirected_to() == "/"
    end
  end

  describe "without scripts, the form has no address to send" do
    test "the Referer says where the visitor was", %{conn: conn} do
      conn =
        conn
        |> put_req_header("referer", "http://www.example.com/en-in/fuel-bill-generator?from=2")
        |> post(~p"/locale", %{"locale" => "hi-in", "from" => ""})

      assert redirected_to(conn) == "/hi-in/fuel-bill-generator?from=2"
    end

    test "but only a Referer from this site", %{conn: conn} do
      for referer <- [
            "https://evil.example/en-in/fuel-bill-generator",
            "not a url",
            "//evil.example/x"
          ] do
        conn =
          conn
          |> put_req_header("referer", referer)
          |> post(~p"/locale", %{"locale" => "hi-in", "from" => ""})

        assert redirected_to(conn) == "/"
      end
    end

    test "and with neither, the home page", %{conn: conn} do
      assert conn |> post(~p"/locale", %{"locale" => "es-es"}) |> redirected_to() == "/"
    end
  end

  test "a visitor who chose is not asked again, and one who chose Spanish does not get Hindi", %{
    conn: conn
  } do
    conn = choose(conn, "hi-in", "/en-in")
    conn = conn |> recycle() |> choose("es-es", "/hi-in/fuel-bill-generator")

    assert redirected_to(conn) == "/es-es/generador-de-factura-de-gasolina"
    assert conn |> recycle() |> get(~p"/") |> redirected_to() == "/es-es"
  end

  describe "when the page's script asks for JSON" do
    defp choose_by_script(conn, locale, from) do
      conn
      |> put_req_header("x-locale-switch", "fetch")
      |> post(~p"/locale", %{"locale" => locale, "from" => from})
    end

    test "answers with where to go (a bill to the same bill is live), and remembers the choice all the same",
         %{conn: conn} do
      conn = choose_by_script(conn, "hi-in", "/en-in/fuel-bill-generator")

      assert %{"to" => "/hi-in/fuel-bill-generator", "live" => true, "lang" => "hi-IN"} =
               json_response(conn, 200)

      assert conn.resp_cookies["qs_locale"].value == "hi-in"
      assert get_session(conn, :locale) == "hi-in"
    end

    test "a page without a locale in its address is a full load", %{conn: conn} do
      conn = choose_by_script(conn, "de-de", "/dashboard")

      assert %{"to" => "/dashboard", "live" => false} = json_response(conn, 200)
    end

    test "a catalogue to a catalogue can be a live navigation", %{conn: conn} do
      conn = choose_by_script(conn, "de-de", "/en-in")

      assert %{"to" => "/de-de", "live" => true, "lang" => "de-DE"} = json_response(conn, 200)
    end

    test "a page that is not in the new language is a full load, which shows the flash", %{
      conn: conn
    } do
      conn = choose_by_script(conn, "hi-in", "/en-in/courier-receipt-generator")

      assert %{"to" => "/hi-in", "live" => false} = json_response(conn, 200)
      assert Phoenix.Flash.get(conn.assigns.flash, :info)
    end
  end
end
