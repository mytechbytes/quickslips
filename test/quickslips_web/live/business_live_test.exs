defmodule QuickSlipsWeb.BusinessLiveTest do
  use QuickSlipsWeb.ConnCase

  import Phoenix.LiveViewTest
  import QuickSlips.BusinessesFixtures

  @create_attrs %{name: "some name", address: "some address", gstin: "29ABCDE1234F1Z5"}
  @update_attrs %{
    name: "some updated name",
    address: "some updated address",
    gstin: "29ABCDE1234F1Z5"
  }
  @invalid_attrs %{name: nil, address: nil, gstin: nil}

  setup :register_and_log_in_user

  defp create_business(%{scope: scope}) do
    business = business_fixture(scope)

    %{business: business}
  end

  describe "Index" do
    setup [:create_business]

    test "lists all businesses", %{conn: conn, business: business} do
      {:ok, _index_live, html} = live(conn, ~p"/businesses")

      assert html =~ "Listing Businesses"
      assert html =~ business.name
    end

    test "saves new business", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/businesses")

      assert {:ok, form_live, _} =
               index_live
               |> element("a", "New Business")
               |> render_click()
               |> follow_redirect(conn, ~p"/businesses/new")

      assert render(form_live) =~ "New Business"

      assert form_live
             |> form("#business-form", business: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#business-form", business: @create_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/businesses")

      html = render(index_live)
      assert html =~ "Business created successfully"
      assert html =~ "some name"
    end

    test "updates business in listing", %{conn: conn, business: business} do
      {:ok, index_live, _html} = live(conn, ~p"/businesses")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#businesses-#{business.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/businesses/#{business}/edit")

      assert render(form_live) =~ "Edit Business"

      assert form_live
             |> form("#business-form", business: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#business-form", business: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/businesses")

      html = render(index_live)
      assert html =~ "Business updated successfully"
      assert html =~ "some updated name"
    end

    test "deletes business in listing", %{conn: conn, business: business} do
      {:ok, index_live, _html} = live(conn, ~p"/businesses")

      assert index_live |> element("#businesses-#{business.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#businesses-#{business.id}")
    end
  end

  describe "Show" do
    setup [:create_business]

    test "displays business", %{conn: conn, business: business} do
      {:ok, _show_live, html} = live(conn, ~p"/businesses/#{business}")

      assert html =~ "Show Business"
      assert html =~ business.name
    end

    test "updates business and returns to show", %{conn: conn, business: business} do
      {:ok, show_live, _html} = live(conn, ~p"/businesses/#{business}")

      assert {:ok, form_live, _} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/businesses/#{business}/edit?return_to=show")

      assert render(form_live) =~ "Edit Business"

      assert form_live
             |> form("#business-form", business: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#business-form", business: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/businesses/#{business}")

      html = render(show_live)
      assert html =~ "Business updated successfully"
      assert html =~ "some updated name"
    end
  end
end
