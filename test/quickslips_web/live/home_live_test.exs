defmodule QuickSlipsWeb.HomeLiveTest do
  use QuickSlipsWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "a visitor" do
    test "sees the public shell and the catalogue", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/en-in")

      assert html =~ "Bills and receipts, ready in seconds"
      assert has_element?(view, "#header-login")
      assert has_element?(view, "#header-signup")
      assert has_element?(view, "#template-fuel-bill")
      refute has_element?(view, "#new-document")
    end

    test "can search the templates", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/en-in")

      view |> form("#template-search-form", %{q: "rent"}) |> render_change()

      assert has_element?(view, "#template-rent-receipt")
      refute has_element?(view, "#template-fuel-bill")
    end

    test "can filter by category", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/en-in")

      view |> element("#chip-travel") |> render_click()

      assert has_element?(view, "#template-fuel-bill")
      refute has_element?(view, "#template-rent-receipt")
      assert has_element?(view, "#chip-travel[aria-pressed=true]")

      view |> element("#chip-all") |> render_click()
      assert has_element?(view, "#template-rent-receipt")
    end

    test "sees nothing when no template matches", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/en-in")

      view |> form("#template-search-form", %{q: "zzz"}) |> render_change()

      refute has_element?(view, "#template-fuel-bill")
      assert has_element?(view, "#no-templates")
    end
  end

  describe "locales" do
    test "the English catalogue links each template to its public address", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/en-in")

      assert has_element?(view, ~s(#open-fuel-bill[href="/en-in/fuel-bill-generator"]))
      assert has_element?(view, ~s(#open-fuel-bill-thumb[href="/en-in/fuel-bill-generator"]))
      # A template whose address changed: the card shows the new one.
      assert has_element?(
               view,
               ~s(#open-taxi-receipt[href="/en-in/cab-bill-generator"]),
               "Cab Bill Generator"
             )

      assert has_element?(view, "#template-rent-receipt")
    end

    test "the Hindi catalogue has the templates that are in Hindi, named in Hindi", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/hi-in")

      assert has_element?(
               view,
               ~s(#open-fuel-bill[href="/hi-in/fuel-bill-generator"]),
               "पेट्रोल बिल जनरेटर"
             )

      refute has_element?(view, "#template-courier-receipt")
      assert has_element?(view, "#chip-travel", "यात्रा")

      # The categories of the bills that are in Hindi: Travel, Home & utilities, Work, Food & shopping and Health &
      # learning (the medical bill), all five.
      assert has_element?(view, "#chip-work")
      assert has_element?(view, "#chip-health-learning")
    end

    test "the Spanish catalogue links to the Spanish address", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/es-es")

      assert has_element?(
               view,
               ~s(#open-fuel-bill[href="/es-es/generador-de-factura-de-gasolina"]),
               "Generador de Factura de Gasolina"
             )

      assert has_element?(view, "#chip-travel", "Viajes")
    end

    test "searching and filtering work in any language", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/hi-in")

      view |> form("#template-search-form", %{q: "पेट्रोल"}) |> render_change()
      assert has_element?(view, "#template-fuel-bill")

      view |> form("#template-search-form", %{q: "zzz"}) |> render_change()
      assert has_element?(view, "#no-templates")

      view |> form("#template-search-form", %{q: ""}) |> render_change()
      view |> element("#chip-travel") |> render_click()
      assert has_element?(view, "#template-fuel-bill")
      assert has_element?(view, "#chip-travel[aria-pressed=true]")
    end

    test "each catalogue names itself and the others to search engines", %{conn: conn} do
      html = conn |> get(~p"/hi-in") |> html_response(200)
      base = QuickSlipsWeb.Endpoint.url()
      document = LazyHTML.from_document(html)

      assert document |> LazyHTML.query("html") |> LazyHTML.attribute("lang") == ["hi-IN"]

      assert document |> LazyHTML.query("link[rel=canonical]") |> LazyHTML.attribute("href") == [
               "#{base}/hi-in"
             ]

      assert document |> LazyHTML.query("link[rel=alternate]") |> LazyHTML.attribute("hreflang") ==
               ~w(en-IN hi-IN es-ES en-US zh-CN de-DE ja-JP en-GB fr-FR it-IT pt-BR en-CA fr-CA x-default)

      assert document |> LazyHTML.query("link[hreflang=x-default]") |> LazyHTML.attribute("href") ==
               ["#{base}/en-in"]
    end

    test "a locale that is not live is a 404", %{conn: conn} do
      assert_error_sent 404, fn -> get(conn, "/es-mx") end
      assert_error_sent 404, fn -> get(conn, "/xx-yy") end
    end

    test "an old template address moves to the new page instead of a catalogue", %{conn: conn} do
      assert conn |> get("/fuel-bill") |> redirected_to(301) == "/en-in/fuel-bill-generator"
    end
  end

  describe "a logged-in user" do
    setup :register_and_log_in_user

    test "sees the app shell around the same catalogue", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/en-in")

      assert has_element?(view, "#new-document")
      assert has_element?(view, "#template-fuel-bill")
      refute has_element?(view, "#header-login")
      refute html =~ "Need more than 2 downloads a day?"
    end
  end
end
