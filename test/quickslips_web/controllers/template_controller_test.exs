defmodule QuickSlipsWeb.TemplateControllerTest do
  use QuickSlipsWeb.ConnCase

  import QuickSlips.AccountsFixtures
  import QuickSlips.BusinessesFixtures

  test "shows a template", %{conn: conn} do
    conn = get(conn, ~p"/fuel-bill")
    assert html_response(conn, 200) =~ "Fuel Bill Generator"
  end

  test "unknown slug is a 404", %{conn: conn} do
    assert_error_sent 404, fn -> get(conn, ~p"/no-such-bill") end
  end

  describe "Turnstile site key" do
    setup do
      previous = Application.get_env(:quickslips, :turnstile)
      Application.put_env(:quickslips, :turnstile, site_key: "test-site-key", secret_key: "x")
      on_exit(fn -> Application.put_env(:quickslips, :turnstile, previous) end)
    end

    test "is on the page for visitors", %{conn: conn} do
      html = conn |> get(~p"/fuel-bill") |> html_response(200)
      assert html =~ ~s(data-turnstile-site-key="test-site-key")
    end

    test "is left out for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      refute conn |> get(~p"/fuel-bill") |> html_response(200) =~ "data-turnstile-site-key"
    end
  end

  describe "saved businesses" do
    test "a logged-in user's own businesses are on the page, and nobody else's", %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      business_fixture(scope, %{name: "Sunrise Fuel Station", gstin: "29ABCDE1234F1Z5"})
      other = user_scope_fixture()
      business_fixture(other, %{name: "Somebody Else's Pump", gstin: "29ABCDE1234F1Z5"})

      html = conn |> get(~p"/fuel-bill") |> html_response(200)

      assert html =~ "Sunrise Fuel Station"
      refute html =~ "Somebody Else"
    end

    test "only the four fields the form needs reach the page", %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      business_fixture(scope, %{gstin: "29ABCDE1234F1Z5"})

      html = conn |> get(~p"/fuel-bill") |> html_response(200)

      refute html =~ "user_id"
      refute html =~ "inserted_at"
    end

    test "a visitor gets an empty list", %{conn: conn} do
      html = conn |> get(~p"/fuel-bill") |> html_response(200)
      assert html =~ ~s(data-businesses="[]")
    end
  end
end
