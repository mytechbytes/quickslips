defmodule QuickSlipsWeb.DashboardLiveTest do
  use QuickSlipsWeb.ConnCase

  import Phoenix.LiveViewTest

  test "redirects visitors to login page", %{conn: conn} do
    assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/dashboard")
    assert path == ~p"/users/log-in"
  end

  describe "when logged in" do
    setup :register_and_log_in_user

    test "shows the dashboard", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")
      assert has_element?(view, "#dashboard")
    end
  end
end
