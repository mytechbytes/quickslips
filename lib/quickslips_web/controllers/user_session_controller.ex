defmodule QuickSlipsWeb.UserSessionController do
  use QuickSlipsWeb, :controller

  alias QuickSlips.Accounts
  alias QuickSlips.AuthLimits
  alias QuickSlips.ClientIp
  alias QuickSlips.Turnstile
  alias QuickSlipsWeb.AuthMessages
  alias QuickSlipsWeb.UserAuth

  def create(conn, %{"_action" => "confirmed"} = params) do
    create(conn, params, gettext("User confirmed successfully."))
  end

  # A log-in with an e-mail address and a password is the one that can be tried again and again by a script, so it has
  # brakes (`QuickSlips.AuthLimits`): it is turned away before the password is looked at when the address of the visitor or
  # the e-mail address has had too many wrong ones, and after a few wrong ones from one address it asks for the Turnstile
  # check as well. The other ways in carry a token that nobody can guess, and have no brake.
  def create(conn, %{"user" => %{"email" => email, "password" => _} = user_params} = params)
      when is_binary(email) and not is_map_key(user_params, "token") do
    ip = ClientIp.key(conn.remote_ip)

    with :ok <- AuthLimits.check_login(ip, email),
         :ok <- check_human(conn, ip, user_params) do
      create(conn, params, gettext("Welcome back!"))
    else
      {:error, reason} -> refuse(conn, reason, email)
    end
  end

  def create(conn, params) do
    create(conn, params, gettext("Welcome back!"))
  end

  # The Turnstile check, asked for only when the address has been wrong several times: the page puts the token in the form
  # whether it is asked for or not, so that it is there when it is.
  defp check_human(conn, ip, user_params) do
    if AuthLimits.captcha_required?(ip) do
      remote_ip = conn.remote_ip |> :inet.ntoa() |> to_string()

      case Turnstile.verify(user_params["turnstile_token"], remote_ip) do
        :ok -> :ok
        {:error, _reason} -> {:error, :check_failed}
      end
    else
      :ok
    end
  end

  defp refuse(conn, reason, email) do
    message =
      case reason do
        :check_failed -> AuthMessages.check_failed()
        {:slow_down, _seconds} -> AuthMessages.too_many_logins()
      end

    conn
    |> put_flash(:error, message)
    |> put_flash(:email, String.slice(email, 0, 160))
    |> redirect(to: ~p"/users/log-in")
  end

  # confirm an account registered with a password: token + password
  defp create(
         conn,
         %{"user" => %{"token" => token, "password" => password} = user_params},
         info
       ) do
    case Accounts.confirm_user_with_password(token, password) do
      {:ok, {user, tokens_to_disconnect}} ->
        UserAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      {:error, _} ->
        conn
        |> put_flash(:error, gettext("That link or password is not valid."))
        |> redirect(to: ~p"/users/log-in")
    end
  end

  # magic link login
  defp create(conn, %{"user" => %{"token" => token} = user_params}, info) do
    case Accounts.login_user_by_magic_link(token) do
      {:ok, {user, tokens_to_disconnect}} ->
        UserAuth.disconnect_sessions(tokens_to_disconnect)

        conn
        |> put_flash(:info, info)
        |> UserAuth.log_in_user(user, user_params)

      _ ->
        conn
        |> put_flash(:error, gettext("The link is invalid or it has expired."))
        |> redirect(to: ~p"/users/log-in")
    end
  end

  # email + password login
  defp create(conn, %{"user" => user_params}, info) do
    %{"email" => email, "password" => password} = user_params

    if user = Accounts.get_user_by_email_and_password(email, password) do
      AuthLimits.clear_login_failures(email)

      conn
      |> put_flash(:info, info)
      |> UserAuth.log_in_user(user, user_params)
    else
      AuthLimits.record_login_failure(ClientIp.key(conn.remote_ip), email)

      # In order to prevent user enumeration attacks, don't disclose whether the email is registered.
      conn
      |> put_flash(:error, gettext("Invalid email or password"))
      |> put_flash(:email, String.slice(email, 0, 160))
      |> redirect(to: ~p"/users/log-in")
    end
  end

  def update_password(conn, %{"user" => user_params} = params) do
    user = conn.assigns.current_scope.user
    true = Accounts.sudo_mode?(user)
    {:ok, {_user, expired_tokens}} = Accounts.update_user_password(user, user_params)

    # disconnect all existing LiveViews with old sessions
    UserAuth.disconnect_sessions(expired_tokens)

    conn
    |> put_session(:user_return_to, ~p"/users/settings")
    |> create(params, gettext("Password updated successfully!"))
  end

  def delete(conn, _params) do
    conn
    |> put_flash(:info, gettext("Logged out successfully."))
    |> UserAuth.log_out_user()
  end
end
