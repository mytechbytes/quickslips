defmodule QuickSlipsWeb.UserLive.RegistrationTest do
  use QuickSlipsWeb.ConnCase, async: true

  import Ecto.Query, only: [from: 2]
  import Phoenix.LiveViewTest
  import QuickSlips.AccountsFixtures
  import QuickSlips.TaskHelpers
  import QuickSlips.TurnstileHelpers
  import Swoosh.TestAssertions

  alias QuickSlips.Accounts.User
  alias QuickSlips.Repo

  describe "Registration page" do
    test "renders registration page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/users/register")

      assert html =~ "Create your account"
      assert html =~ "Log in"
    end

    test "redirects if already logged in", %{conn: conn} do
      result =
        conn
        |> log_in_user(user_fixture())
        |> live(~p"/users/register")
        |> follow_redirect(conn, ~p"/")

      assert {:ok, _conn} = result
    end

    test "renders errors for invalid data", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      result =
        lv
        |> element("#registration_form")
        |> render_change(user: %{"email" => "with spaces"})

      assert result =~ "Create your account"
      assert result =~ "must have the @ sign and no spaces"
    end

    test "renders password fields and live password errors", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      assert has_element?(lv, "#registration_form input[name='user[password]'][type=password]")

      assert has_element?(
               lv,
               "#registration_form input[name='user[password_confirmation]'][type=password]"
             )

      result =
        lv
        |> element("#registration_form")
        |> render_change(
          user: %{
            "email" => "me@example.com",
            "password" => "short",
            "password_confirmation" => "different"
          }
        )

      assert result =~ "should be at least 6 character(s)"
      assert result =~ "does not match password"
    end
  end

  describe "register user" do
    test "creates account but does not log in", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")
      pass_turnstile(lv)

      email = unique_user_email()
      form = form(lv, "#registration_form", user: valid_user_attributes(email: email))

      {:ok, _lv, html} =
        render_submit(form)
        |> follow_redirect(conn, ~p"/users/log-in")

      assert html =~
               ~r/An email was sent to .*, please access it and use the password you just chose to confirm your account/

      assert Repo.get_by!(User, email: email).confirmed_at == nil

      wait_for_tasks()
      assert_email_sent(to: {nil, email})
    end

    test "asks for the Turnstile check", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      assert has_element?(
               lv,
               "#registration-turnstile[phx-hook=AuthTurnstile][phx-update=ignore][data-site-key=test]"
             )
    end

    test "makes no account and sends nothing before the check is passed", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      email = unique_user_email()

      html =
        lv
        |> form("#registration_form", user: valid_user_attributes(email: email))
        |> render_submit()

      assert html =~ "couldn&#39;t check that you are a person"
      assert Repo.get_by(User, email: email) == nil
      wait_for_tasks()
      refute_email_sent()
    end

    test "makes no account when Cloudflare says the visitor is not a person", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")
      turnstile_says(lv, false)
      give_token(lv)

      email = unique_user_email()

      html =
        lv
        |> form("#registration_form", user: valid_user_attributes(email: email))
        |> render_submit()

      assert html =~ "couldn&#39;t check that you are a person"
      assert_push_event(lv, "turnstile:reset", %{})
      assert Repo.get_by(User, email: email) == nil
    end

    test "what is wrong with the form is told before the check, and uses no token", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      html =
        lv
        |> form("#registration_form",
          user: %{
            "email" => unique_user_email(),
            "password" => "Ab1",
            "password_confirmation" => "Ab1"
          }
        )
        |> render_submit()

      assert html =~ "should be at least 6 character(s)"
      refute html =~ "couldn&#39;t check that you are a person"
    end

    test "does not tell that the address has an account: the page says what it says to a new one",
         %{
           conn: conn
         } do
      user = user_fixture(%{email: "test@email.com"})
      {:ok, lv, _html} = live(conn, ~p"/users/register")
      pass_turnstile(lv)

      {:ok, _lv, html} =
        lv
        |> form("#registration_form", user: valid_user_attributes(email: user.email))
        |> render_submit()
        |> follow_redirect(conn, ~p"/users/log-in")

      refute html =~ "has already been taken"

      assert html =~
               ~r/An email was sent to .*, please access it and use the password you just chose to confirm your account/

      # Nothing was made, and the owner of the address is the one who is told.
      assert Repo.aggregate(from(u in User, where: u.email == ^user.email), :count) == 1
      wait_for_tasks()
      assert_email_sent(to: {nil, user.email})
    end

    test "the e-mail of an address that has an account is the log-in link, and the account is not touched",
         %{
           conn: conn
         } do
      user = user_fixture()
      {:ok, lv, _html} = live(conn, ~p"/users/register")
      pass_turnstile(lv)

      attrs =
        valid_user_attributes(
          email: user.email,
          password: "Another pass 99",
          password_confirmation: "Another pass 99"
        )

      lv |> form("#registration_form", user: attrs) |> render_submit()
      wait_for_tasks()

      reloaded = Repo.get!(User, user.id)
      assert reloaded.hashed_password == user.hashed_password

      assert QuickSlips.Repo.get_by!(QuickSlips.Accounts.UserToken, user_id: user.id).context ==
               "login"
    end

    test "does not tell either when the password is wrong too: only the password is told", %{
      conn: conn
    } do
      user = user_fixture()
      {:ok, lv, _html} = live(conn, ~p"/users/register")
      pass_turnstile(lv)

      html =
        lv
        |> form("#registration_form",
          user: %{"email" => user.email, "password" => "Ab1", "password_confirmation" => "Ab1"}
        )
        |> render_submit()

      assert html =~ "should be at least 6 character(s)"
      refute html =~ "has already been taken"
    end
  end

  describe "registration navigation" do
    test "redirects to login page when the Log in button is clicked", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/users/register")

      {:ok, _login_live, login_html} =
        lv
        |> element("main a", "Log in")
        |> render_click()
        |> follow_redirect(conn, ~p"/users/log-in")

      assert login_html =~ "Log in"
    end
  end
end
