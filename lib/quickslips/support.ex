defmodule QuickSlips.Support do
  @moduledoc """
  The page where people can support the site ("Keep QuickSlips free"). India has a page of its own (`:support_url_in`:
  a page that takes rupees and UPI), every other country another (`:support_url`). A country without its own page uses
  the other one, and with neither there is no banner, no bar and no link anywhere.
  """

  @doc "The address of the page to support the site for the country of a locale (`%{country: \"in\"}`), or `nil`."
  def url(%{country: "in"}), do: config(:support_url_in) || config(:support_url)
  def url(_locale), do: config(:support_url)

  defp config(key) do
    case Application.get_env(:quickslips, key) do
      url when is_binary(url) and url != "" -> url
      _none -> nil
    end
  end
end
