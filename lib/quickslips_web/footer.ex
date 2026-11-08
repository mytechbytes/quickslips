defmodule QuickSlipsWeb.Footer do
  @moduledoc """
  The bills the footer of a public page links to, named in the language of the page and at its address.

  A link is only made to a bill that the locale has: a bill that is not in its language (`courier-receipt` in
  Hindi) is left out, never linked to a page that would be a 404.
  """

  alias QuickSlips.Templates

  # What a visitor looks for first, and then the next bills most asked for.
  @popular ~w(fuel-bill rent-receipt restaurant-bill medical-bill taxi-receipt hotel-invoice)
  @more ~w(grocery-bill driver-salary-receipt internet-bill gym-membership-receipt ecommerce-bill)

  @doc "The first group of bill links, `[%{label: \"Fuel Bill\", to: \"/en-in/fuel-bill-generator\"}]`."
  def popular(locale), do: links(@popular, locale)

  @doc "The second group of bill links."
  def more(locale), do: links(@more, locale)

  @doc "The links to the bills with these internal slugs, in this order, that the locale has."
  def links(slugs, locale) do
    names = Templates.names(locale)

    for slug <- slugs, %{name: name, public_slug: public_slug} <- [Map.get(names, slug)] do
      %{label: name, to: "/#{locale.code}/#{public_slug}"}
    end
  end
end
