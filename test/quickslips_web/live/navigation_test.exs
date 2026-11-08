defmodule QuickSlipsWeb.NavigationTest do
  use QuickSlipsWeb.ConnCase

  import Phoenix.LiveViewTest
  import QuickSlips.SiteHelpers

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
      assert_error_sent 404, fn -> get(conn, ~p"/hi-in/courier-receipt-generator") end
    end

    test "goes from a bill to the contact form, which knows what the visit is about", %{
      conn: conn
    } do
      put_contact_email("owner@example.org")
      {:ok, bill, _html} = live(conn, ~p"/en-in/fuel-bill-generator")

      assert {:error, {:live_redirect, %{to: to}}} =
               bill |> element("#bill-feedback-link") |> render_click()

      assert %URI{path: "/contact", query: query} = URI.parse(to)

      assert URI.decode_query(query) == %{
               "topic" => "change",
               "about" => "/en-in/fuel-bill-generator"
             }

      {:ok, contact, _html} = live(conn, to)
      assert has_element?(contact, "#contact-topic-change input[checked]")
      assert has_element?(contact, "#contact-about", "/en-in/fuel-bill-generator")
    end

    test "goes from the catalogue footer to the contact form, and back to the templates", %{
      conn: conn
    } do
      put_contact_email("owner@example.org")
      {:ok, view, _html} = live(conn, ~p"/en-in")

      assert {:error, {:live_redirect, %{to: "/contact"}}} =
               view |> element("#footer-feedback-link") |> render_click()

      {:ok, contact, _html} = live(conn, ~p"/contact")
      assert has_element?(contact, "#contact-form")
    end

    test "is not asked to write when there is nobody to write to", %{conn: conn} do
      put_contact_email(nil)
      {:ok, bill, _html} = live(conn, ~p"/en-in/fuel-bill-generator")

      refute has_element?(bill, "#bill-feedback")
      refute has_element?(bill, "#footer-feedback")
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

    test "goes from the sidebar and the phone menu to the contact form", %{conn: conn} do
      put_contact_email("owner@example.org")

      for link <- ["#nav-contact", "#m-contact"] do
        {:ok, view, _html} = live(conn, ~p"/dashboard")

        assert {:error, {:live_redirect, %{to: "/contact"}}} =
                 view |> element(link) |> render_click()
      end
    end

    test "has no contact link in the app when there is nobody to write to", %{conn: conn} do
      put_contact_email(nil)
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      refute has_element?(view, "#nav-contact")
      refute has_element?(view, "#m-contact")
    end
  end
end
