defmodule QuickSlipsWeb.Seo do
  @moduledoc """
  What the head of a public page tells a search engine or a link preview, as assigns of the page that the root
  layout writes:

    * `canonical_url`: where the page lives;
    * `alternates`: `[{hreflang, url}]`, the other languages and countries that have it (`hreflang` links), with
      `x-default` last, which is the page of the default locale: where a visitor goes whose language none of the
      others fits;
    * `json_ld`: structured data (schema.org) as JSON text: the site and its organisation on a catalogue, and on a
      bill's page the web application, its breadcrumb and its questions and answers (the ones the page shows).

  The sitemap (`QuickSlipsWeb.Sitemap`) uses the same addresses and alternates.
  """
  use Gettext, backend: QuickSlipsWeb.Gettext

  alias QuickSlips.Locales
  alias QuickSlips.Regions
  alias QuickSlips.Templates
  alias QuickSlipsWeb.Endpoint

  @site_name "QuickSlips"
  @social_image "/images/logo-mark-512.png"

  @doc "The name of the site, for `og:site_name` and the structured data."
  def site_name, do: @site_name

  @doc "The picture a link preview shows when a page has none of its own: the mark of the site."
  def social_image, do: url(@social_image)

  @doc "The assigns for the home page of a locale."
  def home(locale) do
    pages = for l <- Locales.live(), do: {l, Locales.path(l)}
    canonical = url(Locales.path(locale))

    %{
      canonical_url: canonical,
      alternates: alternates(pages),
      json_ld: encode(home_graph(locale, canonical))
    }
  end

  @doc "The assigns for the page of a template in a locale. `schema` is what `Templates.get_public/2` gave."
  def bill(locale, schema) do
    slug = schema["slug"]

    pages =
      for {l, public_slug} <- Templates.alternates(slug),
          do: {l, "#{Locales.path(l)}/#{public_slug}"}

    canonical = url(Templates.public_path(slug, locale))

    %{
      canonical_url: canonical,
      alternates: alternates(pages),
      json_ld: encode(bill_graph(locale, schema, canonical))
    }
  end

  @doc """
  Every public page: `[%{url: _, alternates: [{hreflang, url}]}]`. A page is the catalogue of a live locale and each
  bill that is in its language; its alternates are the same page in the other locales. This is the sitemap.
  """
  def pages do
    homes = home_pages()

    bills =
      for locale <- Locales.live(), schema <- Templates.list(locale) do
        slug = schema["slug"]
        %{url: url(Templates.public_path(slug, locale)), alternates: bill_alternates(slug)}
      end

    homes ++ bills
  end

  defp home_pages do
    alternates = alternates(for l <- Locales.live(), do: {l, Locales.path(l)})
    for locale <- Locales.live(), do: %{url: url(Locales.path(locale)), alternates: alternates}
  end

  defp bill_alternates(slug) do
    alternates(
      for {l, public_slug} <- Templates.alternates(slug),
          do: {l, "#{Locales.path(l)}/#{public_slug}"}
    )
  end

  # `[{hreflang, absolute_url}]`, with `x-default` last.
  defp alternates(pages) do
    default = Locales.default().code

    links = for {locale, path} <- pages, do: {Locales.hreflang(locale), url(path)}
    defaults = for {%{code: ^default}, path} <- pages, do: {"x-default", url(path)}

    links ++ defaults
  end

  ## Structured data

  defp home_graph(locale, canonical) do
    description =
      Gettext.with_locale(QuickSlipsWeb.Gettext, locale.language, fn ->
        gettext("Create bills and receipts as PDF in seconds.")
      end)

    %{
      "@context" => "https://schema.org",
      "@graph" => [
        %{
          "@type" => "WebSite",
          "@id" => url("/#website"),
          "url" => canonical,
          "name" => @site_name,
          "description" => description,
          "inLanguage" => Locales.hreflang(locale),
          "publisher" => %{"@id" => url("/#organization")}
        },
        organization()
      ]
    }
  end

  defp bill_graph(locale, schema, canonical) do
    %{
      "@context" => "https://schema.org",
      "@graph" =>
        Enum.reject(
          [
            web_application(locale, schema, canonical),
            breadcrumb(locale, schema, canonical),
            faq_page(schema, canonical),
            organization()
          ],
          &is_nil/1
        )
    }
  end

  defp web_application(locale, schema, canonical) do
    %{
      "@type" => "WebApplication",
      "@id" => canonical <> "#app",
      "name" => schema["title"],
      "description" => schema["description"],
      "url" => canonical,
      "inLanguage" => Locales.hreflang(locale),
      "applicationCategory" => "BusinessApplication",
      "operatingSystem" => "Any",
      "browserRequirements" => "Requires JavaScript",
      "isAccessibleForFree" => true,
      "offers" => %{
        "@type" => "Offer",
        "price" => "0",
        "priceCurrency" => Regions.default_currency(locale.country)
      },
      "publisher" => %{"@id" => url("/#organization")}
    }
  end

  defp breadcrumb(locale, schema, canonical) do
    %{
      "@type" => "BreadcrumbList",
      "itemListElement" => [
        %{
          "@type" => "ListItem",
          "position" => 1,
          "name" => @site_name,
          "item" => url(Locales.path(locale))
        },
        %{"@type" => "ListItem", "position" => 2, "name" => schema["title"], "item" => canonical}
      ]
    }
  end

  # The questions of the page, as the page shows them.
  defp faq_page(%{"faq" => [_ | _] = faq}, canonical) do
    %{
      "@type" => "FAQPage",
      "@id" => canonical <> "#faq",
      "mainEntity" =>
        for %{"q" => question, "a" => answer} <- faq do
          %{
            "@type" => "Question",
            "name" => question,
            "acceptedAnswer" => %{"@type" => "Answer", "text" => answer}
          }
        end
    }
  end

  defp faq_page(_schema, _canonical), do: nil

  defp organization do
    %{
      "@type" => "Organization",
      "@id" => url("/#organization"),
      "name" => @site_name,
      "url" => Endpoint.url(),
      "logo" => social_image()
    }
  end

  # `escape: :html_safe` writes `<` as `<`, so nothing in a text can close the `<script>` it sits in.
  defp encode(graph), do: Jason.encode!(graph, escape: :html_safe)

  defp url(path), do: Endpoint.url() <> path
end
