defmodule QuickSlipsWeb.AuthController do
  use QuickSlipsWeb, :controller

  alias QuickSlips.Accounts
  alias QuickSlipsWeb.SocialLogin
  alias QuickSlipsWeb.UserAuth

  # A provider whose keys are not set (Microsoft, until the app is registered) is not there at all. This has to run before
  # Ueberauth, which would send the visitor to an error page of the provider.
  plug :require_keys

  # Handles /auth/:provider (redirect to Google or Microsoft) and /auth/:provider/callback
  # (fills in conn.assigns.ueberauth_auth or ueberauth_failure) before the action runs.
  plug Ueberauth

  # Only reached for an unknown provider; Ueberauth halts the request for "google" and "microsoft".
  def request(conn, _params), do: unknown_provider(conn)

  def callback(%{assigns: %{ueberauth_failure: failure}} = conn, _params) do
    conn
    |> put_flash(:error, did_not_complete(failure.provider))
    |> redirect(to: ~p"/users/log-in")
  end

  def callback(
        %{assigns: %{ueberauth_auth: %Ueberauth.Auth{provider: provider} = auth}} = conn,
        _params
      ) do
    case Accounts.get_or_register_social_user(provider, SocialLogin.user_info(auth)) do
      {:ok, user} ->
        conn
        |> put_flash(:info, gettext("Welcome!"))
        |> UserAuth.log_in_user(user, %{"remember_me" => "true"})

      {:error, :email_not_verified} ->
        conn
        |> put_flash(:error, email_not_verified(provider))
        |> redirect(to: ~p"/users/log-in")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, could_not_sign_in(provider))
        |> redirect(to: ~p"/users/log-in")
    end
  end

  # The callback address of a provider that is not there: Ueberauth had nothing to answer, so neither of the above.
  def callback(conn, _params), do: unknown_provider(conn)

  defp require_keys(%{path_params: %{"provider" => "microsoft"}} = conn, _opts) do
    if SocialLogin.enabled?(:microsoft), do: conn, else: unknown_provider(conn)
  end

  defp require_keys(conn, _opts), do: conn

  defp unknown_provider(conn) do
    conn
    |> put_status(:not_found)
    |> text("Unknown login provider")
    |> halt()
  end

  # One message per provider and per case, each written out, so that Gettext can find them.
  defp did_not_complete(:microsoft),
    do: gettext("Microsoft sign-in didn't complete. Please try again.")

  defp did_not_complete(:google), do: gettext("Google sign-in didn't complete. Please try again.")

  defp email_not_verified(:microsoft),
    do: gettext("We couldn't get a verified email address from your Microsoft account.")

  defp email_not_verified(:google), do: gettext("Google says that email address isn't verified.")

  defp could_not_sign_in(:microsoft),
    do: gettext("We couldn't sign you in with Microsoft. Please try again.")

  defp could_not_sign_in(:google),
    do: gettext("We couldn't sign you in with Google. Please try again.")
end
