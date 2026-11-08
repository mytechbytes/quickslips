defmodule QuickSlips.Site do
  @moduledoc """
  Facts about the site that its owner sets from the environment (`config/runtime.exs`) and that pages show.
  """

  @doc """
  The address people write to (`CONTACT_EMAIL`), or `nil` when none is set. The legal pages and the footer have a
  contact line only when there is one: an address that was never set is not invented, and the e-mail of whoever
  built the site is not put on a public page by itself.
  """
  def contact_email do
    case Application.get_env(:quickslips, :contact_email) do
      email when is_binary(email) ->
        case String.trim(email) do
          "" -> nil
          trimmed -> trimmed
        end

      _not_set ->
        nil
    end
  end
end
