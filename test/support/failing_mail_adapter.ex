defmodule QuickSlips.FailingMailAdapter do
  @moduledoc """
  A mail adapter for tests of what happens when the mail provider is down: it answers with an error, or with
  `mode: :raise` it raises one, or with `mode: {:fail_to, address}` it fails for the e-mails to that address only
  and delivers the others as the test adapter does.
  """
  use Swoosh.Adapter

  @impl true
  def deliver(email, config) do
    case config[:mode] do
      :raise ->
        raise "the mail provider crashed"

      {:fail_to, address} ->
        if Enum.any?(email.to, fn {_name, to} -> to == address end),
          do: {:error, :provider_down},
          else: Swoosh.Adapters.Test.deliver(email, config)

      _always ->
        {:error, :provider_down}
    end
  end
end
