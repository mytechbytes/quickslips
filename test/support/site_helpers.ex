defmodule QuickSlips.SiteHelpers do
  @moduledoc """
  For tests that depend on a setting of the site. The settings belong to the whole application, so a test module
  that uses these must not be `async`. Each one is put back when the test ends.
  """
  import ExUnit.Callbacks, only: [on_exit: 1]

  @doc "Sets the contact address (`nil` for none)."
  def put_contact_email(email), do: put_setting(:contact_email, email)

  @doc "Sets the daily ceilings of the contact form, like `[user: 2, all: 5, to: 2]`."
  def put_contact_limits(limits), do: put_setting(:contact_limits, limits)

  @doc "Says which addresses are admins (`ADMIN_EMAILS`): the list of lower-case addresses."
  def put_admin_emails(emails), do: put_setting(:admin_emails, emails)

  @doc """
  Sets the keys of the app registered with Microsoft, like `[client_id: "a", client_secret: "b"]`. `[]` is none, and
  there is then no Microsoft sign-in (the tests have keys unless a test says otherwise).
  """
  def put_microsoft_keys(keys), do: put_env(:ueberauth, Ueberauth.Strategy.Microsoft.OAuth, keys)

  defp put_setting(key, value), do: put_env(:quickslips, key, value)

  defp put_env(app, key, value) do
    previous = Application.fetch_env(app, key)
    Application.put_env(app, key, value)

    on_exit(fn ->
      case previous do
        {:ok, old} -> Application.put_env(app, key, old)
        :error -> Application.delete_env(app, key)
      end
    end)
  end
end
