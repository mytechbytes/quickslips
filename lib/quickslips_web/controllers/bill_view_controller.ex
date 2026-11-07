defmodule QuickSlipsWeb.BillViewController do
  @moduledoc """
  What the form of a bill looks like for a document made for another country than its page: the fields (a tax
  rate with that country's rates, a registration number with its pattern, the fields only some countries have),
  the region (money, dates, tax) and the words the layout prints. The "Region & tax" panel of the bill page asks
  for it when the visitor changes the country or the currency, and rebuilds the form and the preview.
  """
  use QuickSlipsWeb, :controller

  alias QuickSlips.Locales
  alias QuickSlips.Regions
  alias QuickSlips.Templates

  action_fallback QuickSlipsWeb.FallbackController

  def show(conn, %{"slug" => slug} = params) do
    with {:ok, page_locale} <- fetch_locale(params["locale"]),
         locale = Locales.with_country(page_locale, params["country"]),
         {:ok, region} <- region(locale, params["currency"]),
         {:ok, schema} <- Templates.get(slug, locale) do
      json(conn, %{
        fields: schema["fields"],
        tax_mode: schema["tax_mode"],
        region: region,
        text: Templates.print_text(slug, locale)
      })
    end
  end

  defp fetch_locale(nil), do: {:ok, Locales.default()}

  defp fetch_locale(code) do
    case Locales.fetch(code) do
      {:ok, locale} -> {:ok, locale}
      :error -> {:error, :unknown_locale}
    end
  end

  defp region(locale, currency) do
    case Regions.build(locale.country, currency, locale.language) do
      {:ok, region} -> {:ok, region}
      {:error, _reason} -> {:error, :unknown_locale}
    end
  end
end
