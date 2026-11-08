defmodule QuickSlipsWeb.FooterTest do
  # The contact address is a setting of the whole application, so these tests run one at a time.
  use QuickSlipsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias QuickSlips.Locales
  alias QuickSlipsWeb.Endpoint
  alias QuickSlipsWeb.Footer
  alias QuickSlipsWeb.Seo

  # The footer of a public page: the bills most asked for, the rest of the catalogue, the site's own pages, the
  # language and country switch and the notice.

  defp document(html), do: LazyHTML.from_document(html)

  # `[{text, href}]` of the links in an element of the footer.
  defp links(doc, selector) do
    for node <- LazyHTML.query(doc, "#{selector} a") do
      {node |> LazyHTML.text() |> String.trim(), node |> LazyHTML.attribute("href") |> hd()}
    end
  end

  defp text(doc, selector),
    do: doc |> LazyHTML.query(selector) |> LazyHTML.text() |> String.trim()

  defp page(conn, path), do: conn |> get(path) |> html_response(200) |> document()

  # The contact address is a setting of the whole application; a test that sets it puts it back.
  defp contact(email) do
    previous = Application.fetch_env(:quickslips, :contact_email)
    Application.put_env(:quickslips, :contact_email, email)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:quickslips, :contact_email, value)
        :error -> Application.delete_env(:quickslips, :contact_email)
      end
    end)
  end

  # The paths of the sitemap, which are the pages that exist.
  defp sitemap_paths do
    base = Endpoint.url()
    MapSet.new(Seo.pages(), &String.replace_prefix(&1.url, base, ""))
  end

  describe "on every public page" do
    test "is there, with its three groups of links", %{conn: conn} do
      for path <- [~p"/en-in", ~p"/en-in/fuel-bill-generator", ~p"/users/log-in", ~p"/sitemap"] do
        doc = page(conn, path)

        for id <- ["site-footer", "footer-popular", "footer-more", "footer-site", "footer-locale"] do
          assert LazyHTML.query(doc, "##{id}") |> Enum.count() == 1, "#{path}: no ##{id}"
        end
      end
    end

    test "has the bills most asked for, each at its page in the locale", %{conn: conn} do
      doc = page(conn, ~p"/en-in")

      assert links(doc, "#footer-popular") == [
               {"Fuel Bill", "/en-in/fuel-bill-generator"},
               {"Rent Receipt", "/en-in/rent-receipt-generator"},
               {"Restaurant Bill", "/en-in/restaurant-bill-generator"},
               {"Medical Bill", "/en-in/medical-bill-generator"},
               {"Cab Bill", "/en-in/cab-bill-generator"},
               {"Hotel Bill", "/en-in/hotel-bill-generator"}
             ]
    end

    test "has more templates, and the way to all of them", %{conn: conn} do
      doc = page(conn, ~p"/en-in")

      assert links(doc, "#footer-more") == [
               {"Grocery Bill", "/en-in/grocery-bill-generator"},
               {"Driver Salary Receipt", "/en-in/driver-salary-receipt-generator"},
               {"Internet Bill", "/en-in/internet-bill-generator"},
               {"Gym Membership Receipt", "/en-in/gym-membership-receipt-generator"},
               {"E-commerce Bill", "/en-in/ecommerce-bill-generator"},
               {"View all templates", "/en-in"}
             ]
    end

    test "has the pages of the site itself", %{conn: conn} do
      doc = page(conn, ~p"/en-in")

      assert links(doc, "#footer-site") == [
               {"Templates", "/en-in"},
               {"Sitemap", "/sitemap"},
               {"Terms", "/terms"},
               {"Privacy", "/privacy"},
               {"Disclaimer", "/disclaimer"}
             ]

      assert text(doc, "#footer-site h2") == "QuickSlips"
    end

    test "has a way to write to the owner once there is an address, and not before", %{conn: conn} do
      contact(nil)

      refute {"Contact", "mailto:hello@example.org"} in links(
               page(conn, ~p"/en-in"),
               "#footer-site"
             )

      assert page(conn, ~p"/en-in")
             |> LazyHTML.query("#footer-site a[href^='mailto:']")
             |> Enum.count() == 0

      contact("hello@example.org")

      assert List.last(links(page(conn, ~p"/en-in"), "#footer-site")) ==
               {"Contact", "mailto:hello@example.org"}

      assert List.last(links(page(conn, ~p"/es-es"), "#footer-site")) ==
               {"Contacto", "mailto:hello@example.org"}
    end

    test "every link to a page of the site itself leads to a page", %{conn: conn} do
      for {_label, "/" <> _ = path} <- links(page(conn, ~p"/en-in"), "#footer-site") do
        assert conn |> get(path) |> html_response(200), path
      end
    end

    test "says what QuickSlips is for, who it belongs to, and who answers for the documents", %{
      conn: conn
    } do
      doc = page(conn, ~p"/en-in")

      assert text(doc, "#footer-tagline") =~ "Make a clean bill or receipt as a PDF in seconds"

      assert text(doc, "#footer-copyright") ==
               "© #{Date.utc_today().year} QuickSlips. All rights reserved."

      assert text(doc, "#footer-notice") =~ "You are responsible for their accuracy"
    end

    test "keeps the language and country switch", %{conn: conn} do
      doc = page(conn, ~p"/en-in")

      assert LazyHTML.query(doc, "#footer-locale-trigger") |> Enum.count() == 1
      assert LazyHTML.query(doc, "#footer-locale-hi-in") |> Enum.count() == 1
    end

    test "is in the language of the page, with the links of its locale", %{conn: conn} do
      es = page(conn, ~p"/es-es")

      assert text(es, "#footer-popular h2") == "Documentos populares"
      assert text(es, "#footer-more h2") == "Más plantillas"

      assert {"Factura de Gasolina", "/es-es/generador-de-factura-de-gasolina"} in links(
               es,
               "#footer-popular"
             )

      assert {"Ver todas las plantillas", "/es-es"} in links(es, "#footer-more")
      assert {"Mapa del sitio", "/sitemap"} in links(es, "#footer-site")
      assert {"Términos", "/terms"} in links(es, "#footer-site")
      assert {"Privacidad", "/privacy"} in links(es, "#footer-site")
      assert {"Descargo de responsabilidad", "/disclaimer"} in links(es, "#footer-site")
      assert text(es, "#footer-copyright") =~ "Todos los derechos reservados."

      hi = page(conn, ~p"/hi-in")
      assert text(hi, "#footer-popular h2") == "लोकप्रिय बिल"
      assert text(hi, "#footer-copyright") =~ "सर्वाधिकार सुरक्षित"
    end

    test "a click on one of its links is a live navigation", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/en-in")

      assert {:error, {:live_redirect, %{to: "/sitemap"}}} =
               view |> element("#footer-site a", "Sitemap") |> render_click()

      {:ok, view, _html} = live(conn, ~p"/en-in")

      assert {:error, {:live_redirect, %{to: "/en-in/fuel-bill-generator"}}} =
               view |> element("#footer-popular a", "Fuel Bill") |> render_click()
    end
  end

  describe "for a logged-in user" do
    setup :register_and_log_in_user

    test "there is none: the app has its own shell", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")
      refute has_element?(view, "#site-footer")

      {:ok, view, _html} = live(conn, ~p"/en-in")
      refute has_element?(view, "#site-footer")
    end
  end

  describe "Footer.links/2" do
    test "makes a link for each bill the locale has, in the order given" do
      locale = Locales.fetch!("de-de")

      assert [
               %{label: "Mietquittung", to: "/de-de/mietquittung-generator"},
               %{label: "Tankrechnung"}
             ] =
               Footer.links(["rent-receipt", "fuel-bill"], locale)
    end

    test "leaves out a bill that is not in the language, and one that does not exist" do
      hindi = Locales.fetch!("hi-in")

      # the courier receipt is English only
      assert [%{to: "/hi-in/fuel-bill-generator"}] =
               Footer.links(["courier-receipt", "nothing-like-it", "fuel-bill"], hindi)
    end
  end

  test "every link to a bill goes to a page that exists, in every locale" do
    pages = sitemap_paths()

    for locale <- Locales.live() do
      popular = Footer.popular(locale)
      more = Footer.more(locale)

      assert length(popular) == 6, locale.code
      assert length(more) == 5, locale.code

      for %{to: to} <- popular ++ more do
        assert to in pages, "#{locale.code}: #{to} is not a page"
        assert String.starts_with?(to, "/#{locale.code}/")
      end
    end
  end
end
