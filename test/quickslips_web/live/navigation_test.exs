defmodule QuickSlipsWeb.NavigationTest do
  use QuickSlipsWeb.ConnCase

  import Phoenix.LiveViewTest

  # Every page of the site is a LiveView of one live session, so a link is a live navigation: the answer to a click
  # is `:live_redirect`, never `:redirect` (which loads a new page).

  describe "a visitor" do
    test "goes from the catalogue to a bill, and back", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/en-in")

      assert {:error, {:live_redirect, %{to: "/en-in/fuel-bill-generator"}}} =
               view |> element("#open-fuel-bill") |> render_click()

      {:ok, bill, _html} = live(conn, ~p"/en-in/fuel-bill-generator")
      assert has_element?(bill, "#bill-app[phx-hook=BillApp][phx-update=ignore]")

      assert {:error, {:live_redirect, %{to: "/en-in"}}} =
               bill |> element("#back-to-templates") |> render_click()

      {:ok, bill, _html} = live(conn, ~p"/en-in/fuel-bill-generator")

      assert {:error, {:live_redirect, %{to: "/en-in"}}} =
               bill |> element("#logo") |> render_click()
    end

    test "goes from a bill to the log-in page", %{conn: conn} do
      {:ok, bill, _html} = live(conn, ~p"/en-in/fuel-bill-generator")

      assert {:error, {:live_redirect, %{to: "/users/log-in"}}} =
               bill |> element("#header-login") |> render_click()
    end

    test "a bill that is not in the language is a 404", %{conn: conn} do
      assert_error_sent 404, fn -> get(conn, ~p"/hi-in/grocery-bill-generator") end
    end
  end

  describe "a logged-in user" do
    setup :register_and_log_in_user

    test "goes from the dashboard to the catalogue of their locale without a new page", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert {:error, {:live_redirect, %{to: "/en-in"}}} =
               view |> element("#dashboard-new-document") |> render_click()
    end

    test "goes from a bill to the dashboard", %{conn: conn} do
      {:ok, bill, _html} = live(conn, ~p"/en-in/fuel-bill-generator")

      assert {:error, {:live_redirect, %{to: "/dashboard"}}} =
               bill |> element("#logo") |> render_click()
    end
  end
end
