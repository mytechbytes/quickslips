defmodule QuickSlipsWeb.DashboardLiveTest do
  use QuickSlipsWeb.ConnCase

  import Phoenix.LiveViewTest
  import QuickSlips.BusinessesFixtures
  import QuickSlips.DocumentsFixtures

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

    test "offers the four most common bills to start with", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      for slug <- ~w(fuel-bill rent-receipt taxi-receipt restaurant-bill) do
        assert has_element?(view, "#quick-#{slug}")
      end

      refute has_element?(view, "#quick-courier-receipt")
    end

    test "starts with zeros and an empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "#stat-documents", "0")
      assert has_element?(view, "#stat-businesses", "0")
      assert has_element?(view, "#recent-empty")
      refute has_element?(view, "#recent-documents")
    end

    test "counts the user's documents and businesses, and lists the last five documents", %{
      conn: conn,
      scope: scope
    } do
      business_fixture(scope)
      business_fixture(scope)
      docs = for n <- 1..6, do: document_fixture(scope, %{title: "Bill number #{n}"})
      document_fixture(QuickSlips.AccountsFixtures.user_scope_fixture(), %{title: "Not mine"})

      {:ok, view, html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "#stat-documents", "6")
      assert has_element?(view, "#stat-businesses", "2")
      assert has_element?(view, "#recent-documents li", "Bill number 6")
      assert has_element?(view, "#recent-download-#{List.last(docs).id}")
      refute has_element?(view, "#recent-#{hd(docs).id}")
      refute html =~ "Not mine"
      assert has_element?(view, "#all-documents")
    end
  end
end
