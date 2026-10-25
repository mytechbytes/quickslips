defmodule QuickSlipsWeb.HomeLiveTest do
  use QuickSlipsWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "a visitor" do
    test "sees the public shell and the catalogue", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/")

      assert html =~ "Bills and receipts, ready in seconds"
      assert has_element?(view, "#header-login")
      assert has_element?(view, "#header-signup")
      assert has_element?(view, "#template-fuel-bill")
      refute has_element?(view, "#new-document")
    end

    test "can search the templates", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> form("#template-search-form", %{q: "rent"}) |> render_change()

      assert has_element?(view, "#template-rent-receipt")
      refute has_element?(view, "#template-fuel-bill")
    end

    test "can filter by category", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> element("#chip-travel") |> render_click()

      assert has_element?(view, "#template-taxi-receipt")
      refute has_element?(view, "#template-rent-receipt")
      assert has_element?(view, "#chip-travel[aria-pressed=true]")

      view |> element("#chip-all") |> render_click()
      assert has_element?(view, "#template-rent-receipt")
    end

    test "sees nothing when no template matches", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      view |> form("#template-search-form", %{q: "zzz"}) |> render_change()

      refute has_element?(view, "#template-fuel-bill")
      assert has_element?(view, "#no-templates")
    end
  end

  describe "a logged-in user" do
    setup :register_and_log_in_user

    test "sees the app shell around the same catalogue", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/")

      assert has_element?(view, "#new-document")
      assert has_element?(view, "#template-fuel-bill")
      refute has_element?(view, "#header-login")
      refute html =~ "Need more than 2 downloads a day?"
    end
  end
end
