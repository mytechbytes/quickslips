defmodule QuickSlipsWeb.SocialLogin do
  @moduledoc """
  What the "Continue with Google" and "Continue with Microsoft" buttons need to know: whether a provider can be used on
  this server, and who the person is according to what the provider answered.

  Google is always offered. Microsoft is optional: its keys come from the app that is registered in the Azure portal
  (`MICROSOFT_CLIENT_ID` and `MICROSOFT_CLIENT_SECRET`, see `config/runtime.exs`). Until both are set there is no button, the
  privacy page does not mention it, and `/auth/microsoft` is a 404 (`QuickSlipsWeb.AuthController`), so the code can be
  deployed before the registration is done and nobody lands on an error page of Microsoft's.
  """

  @microsoft_client Ueberauth.Strategy.Microsoft.OAuth

  @doc "True when `provider` (`:google` or `:microsoft`) can be used on this server."
  def enabled?(:google), do: true

  def enabled?(:microsoft) do
    config = Application.get_env(:ueberauth, @microsoft_client, [])
    set?(config[:client_id]) and set?(config[:client_secret])
  end

  defp set?(value), do: is_binary(value) and String.trim(value) != ""

  @doc """
  The facts that `QuickSlips.Accounts.get_or_register_social_user/2` needs, taken from what Ueberauth got back:
  `%{uid: _, email: _, name: _, avatar_url: _, email_verified?: _}`. Built here, from the provider's answer and never
  from anything the visitor typed or sent.
  """
  def user_info(%Ueberauth.Auth{provider: :google} = auth) do
    %{
      uid: auth.uid,
      email: auth.info.email,
      name: auth.info.name,
      avatar_url: auth.info.image,
      email_verified?: get_in(auth.extra.raw_info.user, ["email_verified"]) == true
    }
  end

  # Microsoft does not say "this address is verified", so the address is chosen with care. It is the sign-in name of the
  # account (the "user principal name", which Ueberauth puts in `info.email`), because Microsoft has checked it: a personal
  # account has the address that its owner proved they own when making it, and in a work or school account the part after
  # the @ has to be a domain that the organisation has verified. The "mail" field is NOT used: whoever runs an organisation
  # can write any address in it, even somebody else's at Gmail, so it would let them into that somebody's account.
  # A guest of an organisation has a made-up name with a "#" in it (maria_gmail.com#EXT#@firm.onmicrosoft.com): not an
  # address anyone can write to, so it is turned away. Microsoft gives no address for a picture (only a download that needs
  # the access token), so there is none.
  def user_info(%Ueberauth.Auth{provider: :microsoft} = auth) do
    email = auth.info.email

    %{
      uid: auth.uid,
      email: if(is_binary(email), do: String.downcase(email)),
      name: auth.info.name,
      avatar_url: nil,
      email_verified?: usable_address?(email)
    }
  end

  defp usable_address?(email) when is_binary(email),
    do: Regex.match?(~r/^[^@,;\s#]+@[^@,;\s#]+\.[^@,;\s#]+$/, email)

  defp usable_address?(_not_a_string), do: false
end
