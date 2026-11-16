defmodule QuickSlipsWeb.UserSessionLimitsTest do
  # Not async: the tests set the rules of the rate limiter, and the answer of Turnstile, which belong to the whole
  # application.
  use QuickSlipsWeb.ConnCase, async: false

  import QuickSlips.AccountsFixtures
  import QuickSlips.RateLimitHelpers

  setup %{conn: conn} do
    # Each test comes from an address of its own, so that the counters of one cannot reach another.
    %{conn: %{conn | remote_ip: unique_ip()}, user: set_password(user_fixture())}
  end

  defp log_in(conn, email, password, extra \\ %{}) do
    post(conn, ~p"/users/log-in", %{
      "user" => Map.merge(%{"email" => email, "password" => password}, extra)
    })
  end

  defp wrong_password(conn, email), do: log_in(conn, email, "Not the password 1")

  defp turnstile_says(success?) do
    Req.Test.stub(QuickSlips.Turnstile, fn conn ->
      Req.Test.json(conn, %{"success" => success?})
    end)
  end

  describe "wrong passwords from one address" do
    test "close the log-in of that address, even for a right password", %{conn: conn, user: user} do
      put_limit(:login_ip, 2, 900)

      wrong_password(conn, user.email)
      wrong_password(conn, user.email)

      conn = log_in(conn, user.email, valid_user_password())

      refute get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Too many log-in attempts"
      # The page shows the address again, so that it is not typed twice
      assert Phoenix.Flash.get(conn.assigns.flash, :email) == user.email
    end

    test "do not close it for another address", %{conn: conn, user: user} do
      put_limit(:login_ip, 2, 900)
      wrong_password(conn, user.email)
      wrong_password(conn, user.email)

      other = %{conn | remote_ip: unique_ip()}
      assert get_session(log_in(other, user.email, valid_user_password()), :user_token)
    end
  end

  describe "wrong passwords for one account" do
    test "close the password log-in of that account, from whichever address", %{
      conn: conn,
      user: user
    } do
      put_limit(:login_email, 2, 900)

      wrong_password(conn, user.email)
      wrong_password(%{conn | remote_ip: unique_ip()}, user.email)

      conn = log_in(%{conn | remote_ip: unique_ip()}, user.email, valid_user_password())

      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Too many log-in attempts"
    end

    test "close an e-mail address that has no account in the same way, so that nothing is told",
         %{
           conn: conn
         } do
      put_limit(:login_email, 2, 900)
      nobody = unique_user_email()

      for _ <- 1..2 do
        conn = wrong_password(conn, nobody)
        assert Phoenix.Flash.get(conn.assigns.flash, :error) == "Invalid email or password"
      end

      conn = wrong_password(conn, nobody)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Too many log-in attempts"
    end

    test "are forgotten by a right password", %{conn: conn, user: user} do
      put_limit(:login_email, 3, 900)

      wrong_password(conn, user.email)
      wrong_password(conn, user.email)
      assert get_session(log_in(conn, user.email, valid_user_password()), :user_token)

      # Two more wrong ones are still allowed: the count started again
      wrong_password(conn, user.email)
      wrong_password(conn, user.email)
      assert get_session(log_in(conn, user.email, valid_user_password()), :user_token)
    end
  end

  describe "the Turnstile check" do
    test "is not asked for until the address has been wrong several times", %{
      conn: conn,
      user: user
    } do
      put_limit(:login_captcha, 2, 900)

      wrong_password(conn, user.email)

      # One wrong password, a right one without a token: in
      assert get_session(log_in(conn, user.email, valid_user_password()), :user_token)
    end

    test "is asked for after that: a right password without a token is not enough", %{
      conn: conn,
      user: user
    } do
      put_limit(:login_captcha, 2, 900)
      wrong_password(conn, user.email)
      wrong_password(conn, user.email)

      conn = log_in(conn, user.email, valid_user_password())

      refute get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/users/log-in"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "check that you are a person"
    end

    test "lets a right password in when Cloudflare says the visitor is a person", %{
      conn: conn,
      user: user
    } do
      put_limit(:login_captcha, 2, 900)
      wrong_password(conn, user.email)
      wrong_password(conn, user.email)
      turnstile_says(true)

      conn = log_in(conn, user.email, valid_user_password(), %{"turnstile_token" => "a-token"})

      assert get_session(conn, :user_token)
      assert redirected_to(conn) == ~p"/"
    end

    test "keeps a right password out when Cloudflare says the visitor is not a person", %{
      conn: conn,
      user: user
    } do
      put_limit(:login_captcha, 2, 900)
      wrong_password(conn, user.email)
      wrong_password(conn, user.email)
      turnstile_says(false)

      conn = log_in(conn, user.email, valid_user_password(), %{"turnstile_token" => "a-token"})

      refute get_session(conn, :user_token)
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "check that you are a person"
    end

    test "is not asked for by the log-in with a link", %{conn: conn, user: user} do
      put_limit(:login_captcha, 1, 900)
      put_limit(:login_ip, 1, 900)
      wrong_password(conn, user.email)

      {token, _hashed_token} = generate_user_magic_link_token(user)
      conn = post(conn, ~p"/users/log-in", %{"user" => %{"token" => token}})

      assert get_session(conn, :user_token)
    end
  end

  describe "changing the password" do
    test "is not held back by the brakes of the log-in", %{conn: conn, user: user} do
      put_limit(:login_ip, 1, 900)
      put_limit(:login_captcha, 1, 900)
      wrong_password(conn, user.email)

      conn =
        conn
        |> log_in_user(user)
        |> post(~p"/users/update-password", %{
          "user" => %{
            "email" => user.email,
            "password" => "A new pass 99",
            "password_confirmation" => "A new pass 99"
          }
        })

      assert redirected_to(conn) == ~p"/users/settings"
      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~ "Password updated"
    end
  end
end
