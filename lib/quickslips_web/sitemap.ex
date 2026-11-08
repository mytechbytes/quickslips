defmodule QuickSlipsWeb.Sitemap do
  @moduledoc """
  The sitemap of the site, `/sitemap.xml`: every public page once (the catalogue of each live locale and each bill in
  its language), with the same page in the other locales as `hreflang` alternates, as the sitemap protocol and
  Google ask for. The pages and their alternates are those of `QuickSlipsWeb.Seo.pages/0`.

  There is no `lastmod`: nothing says when the words of a page last changed, and a date that is not true is worse
  than none.

  The XML names a stylesheet (`priv/sitemap.xsl`, served at `/sitemap.xsl`), so a browser that still runs XSLT draws
  the list as a page grouped by language and country. Browsers are removing XSLT (Chrome stops running it for
  everyone on 17 November 2026), and then they show the plain XML tree: nothing breaks, and a crawler never looks at
  the stylesheet. For people, `QuickSlipsWeb.SitemapLive` (`/sitemap`) is the page that always works.
  """

  alias QuickSlips.Locales
  alias QuickSlips.Templates
  alias QuickSlipsWeb.Seo

  @doc "The sitemap as XML text. `pages` are `QuickSlipsWeb.Seo.pages/0` unless a test gives others."
  def xml(pages \\ Seo.pages()) do
    entries = for page <- pages, do: entry(page)

    IO.iodata_to_binary([
      ~s(<?xml version="1.0" encoding="UTF-8"?>\n),
      ~s(<?xml-stylesheet type="text/xsl" href="/sitemap.xsl"?>\n),
      ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n),
      entries,
      "</urlset>\n"
    ])
  end

  @doc """
  The same pages for people (`QuickSlipsWeb.SitemapLive`): for each live locale its catalogue and its bills by
  category, named in its language:

      [%{locale: locale, home: "/en-in", count: 35,
         categories: [%{name: "Travel", bills: [%{name: "Fuel Bill", path: "/en-in/fuel-bill-generator"}]}]}]

  `count` is the number of pages of the locale, the catalogue included. The pages are the ones `xml/1` lists.
  """
  def groups do
    for locale <- Locales.live() do
      names = Templates.names(locale)

      categories =
        for %{key: key, name: name} <- Templates.categories(locale),
            bills = category_bills(names, key, locale),
            bills != [],
            do: %{name: name, bills: bills}

      %{
        locale: locale,
        home: Locales.path(locale),
        categories: categories,
        count: 1 + Enum.sum(for category <- categories, do: length(category.bills))
      }
    end
  end

  defp category_bills(names, category, locale) do
    for {_id, %{category: ^category} = bill} <- names do
      %{name: bill.name, path: "/#{locale.code}/#{bill.public_slug}"}
    end
    |> Enum.sort_by(&String.downcase(&1.name))
  end

  defp entry(%{url: url, alternates: alternates}) do
    [
      "  <url>\n    <loc>",
      escape(url),
      "</loc>\n",
      for {hreflang, href} <- alternates do
        [
          ~s(    <xhtml:link rel="alternate" hreflang="),
          escape(hreflang),
          ~s(" href="),
          escape(href),
          ~s("/>\n)
        ]
      end,
      "  </url>\n"
    ]
  end

  defp escape(text) do
    text
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end
end
