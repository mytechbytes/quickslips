defmodule QuickSlipsWeb.Seo do
  @moduledoc """
  The links in the head of a page that tell a search engine where the page lives (`canonical`) and which other
  languages have it (`hreflang`). They are assigns of the page (`canonical_url` and `alternates`), and the root
  layout writes them.

  `x-default` is the page of the default locale: where a visitor goes whose language none of the others fits.
  """

  alias QuickSlips.Locales
  alias QuickSlips.Templates
  alias QuickSlipsWeb.Endpoint

  @doc "The assigns for the home page of a locale."
  def home(locale) do
    pages = for l <- Locales.live(), do: {l, Locales.path(l)}
    %{canonical_url: url(Locales.path(locale)), alternates: alternates(pages)}
  end

  @doc "The assigns for the page of a template (its internal slug) in a locale."
  def bill(locale, slug) do
    pages =
      for {l, public_slug} <- Templates.alternates(slug),
          do: {l, "#{Locales.path(l)}/#{public_slug}"}

    %{
      canonical_url: url(Templates.public_path(slug, locale)),
      alternates: alternates(pages)
    }
  end

  # `[{hreflang, absolute_url}]`, with `x-default` last.
  defp alternates(pages) do
    default = Locales.default().code

    links = for {locale, path} <- pages, do: {Locales.hreflang(locale), url(path)}
    defaults = for {%{code: ^default}, path} <- pages, do: {"x-default", url(path)}

    links ++ defaults
  end

  defp url(path), do: Endpoint.url() <> path
end
