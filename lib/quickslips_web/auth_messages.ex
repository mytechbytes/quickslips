defmodule QuickSlipsWeb.AuthMessages do
  @moduledoc """
  What the log-in and sign-up pages say when one of their brakes holds a visitor back (`QuickSlips.AuthLimits`), in the
  language of the page. The same words are used by the pages (LiveViews) and by the log-in with a password (a controller).
  """
  use Gettext, backend: QuickSlipsWeb.Gettext

  @doc "The Turnstile check was not passed: none, a bad token, or Cloudflare could not be reached."
  def check_failed do
    gettext(
      "We couldn't check that you are a person. Reload the page and try again, or continue with Google."
    )
  end

  @doc "Too many e-mails were asked for (from this address, for this e-mail address, or from the whole site)."
  def too_many_mails, do: gettext("Too many e-mails were asked for. Please try again later.")

  @doc "Too many wrong passwords (from this address or for this e-mail address)."
  def too_many_logins,
    do: gettext("Too many log-in attempts. Please wait a few minutes and try again.")
end
