defmodule QuickSlipsWeb.SitemapControllerTest do
  use QuickSlipsWeb.ConnCase

  alias QuickSlips.Locales
  alias QuickSlips.Templates
  alias QuickSlipsWeb.Endpoint
  alias QuickSlipsWeb.Sitemap

  # The sitemap as `[%{loc: url, alternates: [{hreflang, href}]}]`.
  defp parse(xml) do
    {document, _rest} =
      xml |> String.to_charlist() |> :xmerl_scan.string(namespace_conformant: true)

    urls = :xmerl_xpath.string(~c"//*[local-name()='url']", document)

    for url <- urls do
      %{
        loc: text(url, ~c"*[local-name()='loc']"),
        alternates:
          for link <- :xmerl_xpath.string(~c"*[local-name()='link']", url) do
            {attribute(link, :hreflang), attribute(link, :href)}
          end
      }
    end
  end

  defp text(node, path) do
    [element] = :xmerl_xpath.string(path, node)
    {:xmlElement, _, _, _, _, _, _, _, [{:xmlText, _, _, _, value, _}], _, _, _} = element
    List.to_string(value)
  end

  defp attribute(node, name) do
    {:xmlElement, _, _, _, _, _, _, attributes, _, _, _, _} = node
    {:xmlAttribute, ^name, _, _, _, _, _, _, value, _} = List.keyfind(attributes, name, 1)
    List.to_string(value)
  end

  setup %{conn: conn} do
    conn = get(conn, ~p"/sitemap.xml")
    %{conn: conn, pages: parse(response(conn, 200))}
  end

  test "is XML that a crawler may keep for an hour", %{conn: conn} do
    assert ["application/xml" <> _] = get_resp_header(conn, "content-type")
    assert get_resp_header(conn, "cache-control") == ["public, max-age=3600"]
    assert "<?xml" <> _ = response(conn, 200)
  end

  test "sets no cookie: a crawler gets the same answer as everybody", %{conn: conn} do
    assert get_resp_header(conn, "set-cookie") == []
  end

  test "has every public page once, as an absolute address", %{pages: pages} do
    locs = Enum.map(pages, & &1.loc)

    assert length(locs) == length(Enum.uniq(locs))
    assert Enum.all?(locs, &String.starts_with?(&1, Endpoint.url() <> "/"))

    # A catalogue for each live locale, and a page for each bill in the language of each locale.
    bills = Enum.sum(for locale <- Locales.live(), do: length(Templates.list(locale)))
    assert length(pages) == length(Locales.live()) + bills
  end

  test "names the same page in every locale it is in, and itself", %{pages: pages} do
    home = Enum.find(pages, &(&1.loc == Endpoint.url() <> "/hi-in"))

    assert Enum.map(home.alternates, &elem(&1, 0)) ==
             Enum.map(Locales.live(), &Locales.hreflang/1) ++ ["x-default"]

    assert {"hi-IN", Endpoint.url() <> "/hi-in"} in home.alternates
    # x-default is the catalogue of the default locale
    assert {"x-default", Endpoint.url() <> "/en-in"} in home.alternates
  end

  test "every page is among its own alternates", %{pages: pages} do
    for %{loc: loc, alternates: alternates} <- pages do
      assert loc in Enum.map(alternates, &elem(&1, 1)), loc
    end
  end

  test "a bill in every language is in every locale, with its own address in each", %{
    pages: pages
  } do
    fuel = Enum.find(pages, &(&1.loc == Endpoint.url() <> "/en-in/fuel-bill-generator"))

    assert length(fuel.alternates) == length(Locales.live()) + 1

    assert {"es-ES", Endpoint.url() <> "/es-es/generador-de-factura-de-gasolina"} in fuel.alternates

    assert {"en-GB", Endpoint.url() <> "/en-gb/fuel-bill-generator"} in fuel.alternates
    assert {"x-default", Endpoint.url() <> "/en-in/fuel-bill-generator"} in fuel.alternates
  end

  test "every alternate is itself a page of the sitemap", %{pages: pages} do
    locs = MapSet.new(pages, & &1.loc)

    for %{loc: loc, alternates: alternates} <- pages, {_hreflang, href} <- alternates do
      assert href in locs, "#{loc} names #{href}, which is not in the sitemap"
    end
  end

  test "a bill that is only in English is only in the English locales", %{pages: pages} do
    courier = Enum.filter(pages, &String.contains?(&1.loc, "courier-receipt-generator"))
    english = Enum.filter(Locales.live(), &(&1.language == "en"))

    assert Enum.map(courier, & &1.loc) |> Enum.sort() ==
             english
             |> Enum.map(&"#{Endpoint.url()}/#{&1.code}/courier-receipt-generator")
             |> Enum.sort()

    # four English locales, and x-default
    assert length(hd(courier).alternates) == length(english) + 1
    refute Enum.any?(pages, &String.contains?(&1.loc, "/hi-in/courier"))
  end

  test "has nothing a crawler is told to stay away from", %{pages: pages} do
    for %{loc: loc} <- pages do
      refute loc =~
               ~r{/(api|uploads|source|users|dashboard|businesses|signatures|history|admin)(/|$)},
             loc
    end
  end

  describe "xml/1" do
    test "writes an address with the characters XML reserves as text" do
      xml =
        Sitemap.xml([
          %{
            url: "https://example.org/a?x=1&y=<2>",
            alternates: [{"en-IN", "https://example.org/a?x=\"1\"&y='2'"}]
          }
        ])

      assert xml =~ "<loc>https://example.org/a?x=1&amp;y=&lt;2&gt;</loc>"
      assert xml =~ ~s(href="https://example.org/a?x=&quot;1&quot;&amp;y=&apos;2&apos;")
      assert [%{loc: "https://example.org/a?x=1&y=<2>"}] = parse(xml)
    end

    test "is a valid empty sitemap with no pages" do
      assert parse(Sitemap.xml([])) == []
    end
  end
end
