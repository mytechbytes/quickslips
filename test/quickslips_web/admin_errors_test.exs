defmodule QuickSlipsWeb.AdminErrorsTest do
  use QuickSlipsWeb.ConnCase

  import Phoenix.LiveViewTest

  setup do
    previous = Application.get_env(:quickslips, :admin_emails)
    on_exit(fn -> Application.put_env(:quickslips, :admin_emails, previous) end)
  end

  test "a visitor is sent to log in", %{conn: conn} do
    assert conn |> get(~p"/admin/errors") |> redirected_to() == ~p"/users/log-in"
  end

  describe "a logged-in user who is not an admin" do
    setup :register_and_log_in_user

    test "gets a 404, as if the page did not exist", %{conn: conn} do
      assert_error_sent 404, fn -> get(conn, ~p"/admin/errors") end
    end
  end

  describe "an admin" do
    setup :register_and_log_in_user

    test "opens the dashboard", %{conn: conn, user: user} do
      Application.put_env(:quickslips, :admin_emails, [String.downcase(user.email)])

      {:ok, _view, html} = live(conn, ~p"/admin/errors")
      assert html =~ "ErrorTracker"
    end
  end
end
