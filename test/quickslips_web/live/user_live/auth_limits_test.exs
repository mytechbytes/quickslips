defmodule QuickSlipsWeb.UserLive.AuthLimitsTest do
  # Not async: the tests set the rules of the rate limiter, which belong to the whole application.
  use QuickSlipsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import QuickSlips.AccountsFixtures
  import QuickSlips.RateLimitHelpers
  import QuickSlips.TaskHelpers
  import QuickSlips.TurnstileHelpers
  import Swoosh.TestAssertions

  alias QuickSlips.Accounts.User
  alias QuickSlips.Repo

  setup %{conn: conn} do
    # Each test comes from an address of its own, so that the counters of one cannot reach another.
    %{conn: %{conn | remote_ip: unique_ip()}}
  end

  # One visit of the page, with the check passed: what a person does before sending the form. The answer is `:sent`
  # (the page moved on, as it does when it has sent the e-mail), `:too_many` (it says so and stays), or the page.
  defp ask_for_link(conn, email) do
    {:ok, lv, _html} = live(conn, ~p"/users/log-in")
    pass_turnstile(lv)
    lv |> form("#login_form_magic", user: %{email: email}) |> render_submit() |> outcome()
  end

  defp sign_up(conn, attrs) do
    {:ok, lv, _html} = live(conn, ~p"/users/register")
    pass_turnstile(lv)

    lv
    |> form("#registration_form", user: valid_user_attributes(attrs))
    |> render_submit()
    |> outcome()
  end

  defp outcome({:error, {:live_redirect, %{to: "/users/log-in"}}}), do: :sent

  defp outcome(html) when is_binary(html) do
    if html =~ "Too many e-mails were asked for", do: :too_many, else: {:page, html}
  end

  describe "the link by e-mail" do
    test "is sent a few times to one address, then refused", %{conn: conn} do
      put_limit(:mail_email, 2, 3600)
      user = user_fixture()

      assert ask_for_link(conn, user.email) == :sent
      assert ask_for_link(conn, user.email) == :sent
      assert ask_for_link(conn, user.email) == :too_many

      wait_for_tasks()
      assert_email_sent(to: {nil, user.email})
      assert_email_sent(to: {nil, user.email})
      refute_email_sent()
    end

    test "refuses an address that has no account in the same way, so that the limit tells nothing",
         %{
           conn: conn
         } do
      put_limit(:mail_email, 1, 3600)
      nobody = unique_user_email()

      assert ask_for_link(conn, nobody) == :sent
      assert ask_for_link(conn, nobody) == :too_many
    end

    test "is refused to a visitor who asks for too many, whatever the addresses", %{conn: conn} do
      put_limit(:mail_ip, 2, 3600)

      assert ask_for_link(conn, unique_user_email()) == :sent
      assert ask_for_link(conn, unique_user_email()) == :sent
      assert ask_for_link(conn, unique_user_email()) == :too_many

      # Another visitor is not held back
      other = %{conn | remote_ip: unique_ip()}
      assert ask_for_link(other, unique_user_email()) == :sent
    end

    test "is refused when the whole site has sent too many", %{conn: conn} do
      put_limit(:mail_all, 1, 3600)
      QuickSlips.RateLimit.forget(:mail_all, :all)

      assert ask_for_link(conn, unique_user_email()) == :sent
      assert ask_for_link(conn, unique_user_email()) == :too_many
    end

    test "does not count a try that failed the check", %{conn: conn} do
      put_limit(:mail_email, 1, 3600)
      user = user_fixture()

      {:ok, lv, _html} = live(conn, ~p"/users/log-in")
      html = lv |> form("#login_form_magic", user: %{email: user.email}) |> render_submit()
      assert html =~ "check that you are a person"

      # The one e-mail that is allowed is still there to be used
      assert ask_for_link(conn, user.email) == :sent
      wait_for_tasks()
    end
  end

  describe "the sign-up" do
    test "is refused to a visitor who signs up too often, whatever the addresses", %{conn: conn} do
      put_limit(:mail_ip, 1, 3600)

      assert sign_up(conn, %{}) == :sent
      email = unique_user_email()

      assert sign_up(conn, %{email: email}) == :too_many
      assert Repo.get_by(User, email: email) == nil
      wait_for_tasks()
    end

    test "is refused for an address that has been asked for too often, whether it has an account or not",
         %{
           conn: conn
         } do
      put_limit(:mail_email, 1, 3600)
      user = user_fixture()

      # The first is told what is told to a new address (the address has an account, and only its owner learns it)
      assert sign_up(conn, %{email: user.email}) == :sent
      assert sign_up(conn, %{email: user.email}) == :too_many
      wait_for_tasks()
    end

    test "does not count a form that is not good, and does not use up the check", %{conn: conn} do
      put_limit(:mail_email, 1, 3600)
      email = unique_user_email()

      {:ok, lv, _html} = live(conn, ~p"/users/register")
      pass_turnstile(lv)

      html =
        lv
        |> form("#registration_form",
          user: %{"email" => email, "password" => "Ab1", "password_confirmation" => "Ab1"}
        )
        |> render_submit()

      assert html =~ "should be at least 6 character(s)"

      # The same page, the same token: a good form now goes through, and the one e-mail was not used up
      lv
      |> form("#registration_form", user: valid_user_attributes(email: email))
      |> render_submit()

      assert_redirect(lv, ~p"/users/log-in")
      assert Repo.get_by(User, email: email)
      wait_for_tasks()
    end
  end

  describe "the address of the visitor" do
    test "is the one of the request that loaded the page, which a LiveView cannot see otherwise",
         %{
           conn: conn
         } do
      put_limit(:mail_ip, 1, 3600)

      # Two visitors on two addresses, each sending one: neither is held back
      assert ask_for_link(conn, unique_user_email()) == :sent
      assert ask_for_link(%{conn | remote_ip: unique_ip()}, unique_user_email()) == :sent

      # The first visitor again: held back
      assert ask_for_link(conn, unique_user_email()) == :too_many
    end
  end
end
