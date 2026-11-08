defmodule QuickSlipsWeb.SitemapLiveTest do
  use QuickSlipsWeb.ConnCase

  import Phoenix.LiveViewTest

  alias QuickSlips.Locales
  alias QuickSlipsWeb.Endpoint
  alias QuickSlipsWeb.Seo
  alias QuickSlipsWeb.Sitemap

  # The page of every public page, for people; the XML (`/sitemap.xml`) is for search engines.

  defp sitemap_paths do
    base = Endpoint.url()
    MapSet.new(Seo.pages(), &String.replace_prefix(&1.url, base, ""))
  end

  defp document(html), do: LazyHTML.from_document(html)

  test "is there for everybody, with a group for each language and country", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sitemap")

    for locale <- Locales.live() do
      assert has_element?(view, "#sitemap-#{locale.code}"), locale.code
    end

    assert has_element?(view, "h1", "Sitemap")
  end

  test "says how many pages and groups there are", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sitemap")

    assert has_element?(view, "#sitemap-summary", "Pages: #{length(Seo.pages())}")

    assert has_element?(
             view,
             "#sitemap-summary",
             "Languages and countries: #{length(Locales.live())}"
           )
  end

  test "points to the XML that search engines read", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sitemap")

    assert has_element?(view, ~s(#sitemap-xml-link[href="/sitemap.xml"]), "sitemap.xml")
  end

  test "lists the same pages as the XML, and no others", %{conn: conn} do
    html = conn |> get(~p"/sitemap") |> html_response(200)

    listed =
      html
      |> document()
      |> LazyHTML.query("#sitemap-page details a[href^='/']")
      |> Enum.flat_map(&LazyHTML.attribute(&1, "href"))

    assert length(listed) == length(Enum.uniq(listed))
    assert MapSet.new(listed) == sitemap_paths()
  end

  test "names each page in the language of its locale, by kind of bill", %{conn: conn} do
    html = conn |> get(~p"/sitemap") |> html_response(200) |> document()

    link = fn group, path ->
      html
      |> LazyHTML.query("#sitemap-#{group} a[href='#{path}']")
      |> LazyHTML.text()
      |> String.trim()
    end

    assert link.("es-es", "/es-es/generador-de-factura-de-gasolina") == "Factura de Gasolina"
    assert link.("hi-in", "/hi-in/fuel-bill-generator") == "पेट्रोल बिल"
    assert link.("en-in", "/en-in/fuel-bill-generator") == "Fuel Bill"

    categories =
      html
      |> LazyHTML.query("#sitemap-en-in h2")
      |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))

    assert "Travel" in categories
    # the language of a group is marked, for a screen reader and for the browser's fonts
    assert html |> LazyHTML.query("#sitemap-ja-jp [lang=ja]") |> Enum.count() >= 2
  end

  test "has the catalogue of each locale at the head of its group", %{conn: conn} do
    html = conn |> get(~p"/sitemap") |> html_response(200) |> document()

    for locale <- Locales.live() do
      assert html
             |> LazyHTML.query("#sitemap-#{locale.code} a[href='/#{locale.code}']")
             |> Enum.count() == 1
    end
  end

  test "opens the group of the visitor's own locale, and leaves the others closed", %{conn: conn} do
    # the session remembers the locale of the last page
    html =
      conn
      |> get(~p"/hi-in")
      |> recycle()
      |> get(~p"/sitemap")
      |> html_response(200)
      |> document()

    assert html |> LazyHTML.query("#sitemap-hi-in[open]") |> Enum.count() == 1
    assert html |> LazyHTML.query("#sitemap-en-in[open]") |> Enum.count() == 0
    assert html |> LazyHTML.query("details[open]") |> Enum.count() == 1
  end

  test "speaks the language of the visitor", %{conn: conn} do
    html =
      conn
      |> get(~p"/es-es")
      |> recycle()
      |> get(~p"/sitemap")
      |> html_response(200)
      |> document()

    assert html |> LazyHTML.query("#sitemap-page h1") |> LazyHTML.text() |> String.trim() ==
             "Mapa del sitio"

    assert html |> LazyHTML.query("#sitemap-summary") |> LazyHTML.text() =~
             "Páginas: #{length(Seo.pages())}"
  end

  test "every group says how many pages it has, as many as it lists", %{conn: conn} do
    for %{locale: locale, count: count} <- Sitemap.groups() do
      {:ok, view, _html} = live(conn, ~p"/sitemap")

      listed =
        view
        |> element("#sitemap-#{locale.code}")
        |> render()
        |> document()
        |> LazyHTML.query("a[href^='/']")
        |> Enum.count()

      assert listed == count, locale.code
    end
  end

  test "is a page of the site: the footer is there, and a click on a bill is a live navigation",
       %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sitemap")

    assert has_element?(view, "#site-footer")

    assert {:error, {:live_redirect, %{to: "/en-in/fuel-bill-generator"}}} =
             view |> element("#sitemap-en-in a", "Fuel Bill") |> render_click()
  end

  describe "Sitemap.groups/0" do
    test "has a group for each live locale, with its catalogue and its bills by category" do
      groups = Sitemap.groups()

      assert Enum.map(groups, & &1.locale.code) == Enum.map(Locales.live(), & &1.code)

      english = Enum.find(groups, &(&1.locale.code == "en-in"))
      assert english.home == "/en-in"
      # 34 bills and the catalogue
      assert english.count == 35

      assert %{bills: bills} = Enum.find(english.categories, &(&1.name == "Travel"))
      assert %{path: "/en-in/fuel-bill-generator"} = Enum.find(bills, &(&1.name == "Fuel Bill"))
    end

    test "has no bill the language does not have" do
      hindi = Enum.find(Sitemap.groups(), &(&1.locale.code == "hi-in"))
      paths = for category <- hindi.categories, bill <- category.bills, do: bill.path

      refute "/hi-in/courier-receipt-generator" in paths
      assert hindi.count == 31
    end

    test "has each bill once, and the bills of a category by name" do
      for %{locale: locale, categories: categories} <- Sitemap.groups() do
        paths = for category <- categories, bill <- category.bills, do: bill.path
        assert paths == Enum.uniq(paths), locale.code

        for %{bills: bills} <- categories do
          names = Enum.map(bills, &String.downcase(&1.name))
          assert names == Enum.sort(names), locale.code
        end
      end
    end
  end
end
