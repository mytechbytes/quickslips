defmodule QuickSlipsWeb.Sitemap do
  @moduledoc """
  The sitemap of the site, `/sitemap.xml`: every public page once (the catalogue of each live locale and each bill in
  its language), with the same page in the other locales as `hreflang` alternates, as the sitemap protocol and
  Google ask for. The pages and their alternates are those of `QuickSlipsWeb.Seo.pages/0`.

  There is no `lastmod`: nothing says when the words of a page last changed, and a date that is not true is worse
  than none.
  """

  alias QuickSlipsWeb.Seo

  @doc "The sitemap as XML text. `pages` are `QuickSlipsWeb.Seo.pages/0` unless a test gives others."
  def xml(pages \\ Seo.pages()) do
    entries = for page <- pages, do: entry(page)

    IO.iodata_to_binary([
      ~s(<?xml version="1.0" encoding="UTF-8"?>\n),
      ~s(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n),
      entries,
      "</urlset>\n"
    ])
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
