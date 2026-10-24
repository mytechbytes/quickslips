defmodule QuickSlipsWeb.AuthController do
  use QuickSlipsWeb, :controller

  alias QuickSlips.Accounts
  alias QuickSlipsWeb.UserAuth

  # Handles /auth/:provider (redirect to Google) and /auth/:provider/callback
  # (fills in conn.assigns.ueberauth_auth or ueberauth_failure) before the action runs.
  plug Ueberauth

  # Only reached for an unknown provider; Ueberauth halts the request for "google".
  def request(conn, _params) do
    conn
    |> put_status(:not_found)
    |> text("Unknown login provider")
  end

  def callback(%{assigns: %{ueberauth_failure: _failure}} = conn, _params) do
    conn
    |> put_flash(:error, "Google sign-in didn't complete. Please try again.")
    |> redirect(to: ~p"/users/log-in")
  end

  def callback(%{assigns: %{ueberauth_auth: auth}} = conn, _params) do
    case Accounts.get_or_register_google_user(google_info(auth)) do
      {:ok, user} ->
        IO.inspect(auth, label: "GOOGLE")
        conn
        |> put_flash(:info, "Welcome!")
        |> UserAuth.log_in_user(user, %{"remember_me" => "trueß"})

      {:error, :email_not_verified} ->
        conn
        |> put_flash(:error, "Google says that email address isn't verified.")
        |> redirect(to: ~p"/users/log-in")

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "We couldn't sign you in with Google. Please try again.")
        |> redirect(to: ~p"/users/log-in")
    end
  end

  defp google_info(%Ueberauth.Auth{} = auth) do
    %{
      google_uid: auth.uid,
      email: auth.info.email,
      name: auth.info.name,
      avatar_url: auth.info.image,
      email_verified?: get_in(auth.extra.raw_info.user, ["email_verified"]) == true
    }
  end
end
