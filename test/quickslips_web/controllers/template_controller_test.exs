defmodule QuickSlipsWeb.TemplateControllerTest do
  use QuickSlipsWeb.ConnCase

  import QuickSlips.AccountsFixtures
  import QuickSlips.BusinessesFixtures
  import QuickSlips.DocumentsFixtures

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

    test "only the fields the form needs reach the page", %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      business_fixture(scope, %{gstin: "29ABCDE1234F1Z5"})

      html = conn |> get(~p"/fuel-bill") |> html_response(200)

      refute html =~ "user_id"
      refute html =~ "inserted_at"
      refute html =~ "logo_path"
    end

    test "the web addresses of the pictures are on the page, not the stored paths", %{conn: conn} do
      %{conn: conn, user: user, scope: scope} = register_and_log_in_user(%{conn: conn})
      logo = QuickSlips.UploadsFixtures.stored_image(user.id)
      business_fixture(scope, %{name: "Sunrise Fuel Station"}, %{logo_path: logo})

      html = conn |> get(~p"/fuel-bill") |> html_response(200)

      assert html =~ "/uploads/#{logo}"
      assert html =~ "&quot;signature_url&quot;:null"
    end

    test "a visitor gets an empty list", %{conn: conn} do
      html = conn |> get(~p"/fuel-bill") |> html_response(200)
      assert html =~ ~s(data-businesses="[]")
    end
  end

  describe "edit and regenerate" do
    defp earlier(scope, attrs \\ %{}, business \\ nil) do
      sample = "priv/bill_templates/fuel-bill/sample.json" |> File.read!() |> Jason.decode!()
      data = Map.put(sample, "station_name", "Edited Station")
      document_fixture(scope, Map.merge(%{data: data}, attrs), business)
    end

    test "the form starts with the data of the earlier document", %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      doc = earlier(scope)

      html = conn |> get(~p"/fuel-bill?from=#{doc.id}") |> html_response(200)

      assert html =~ "Edited Station"
      refute html =~ "Sunrise Fuel Station"
    end

    test "the business of the earlier document is named, so it can be selected again", %{
      conn: conn
    } do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      business = business_fixture(scope)
      doc = earlier(scope, %{}, business)

      html = conn |> get(~p"/fuel-bill?from=#{doc.id}") |> html_response(200)

      assert html =~ ~s(data-business-id="#{business.id}")
    end

    test "without a business, there is no business id on the page", %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      doc = earlier(scope)

      html = conn |> get(~p"/fuel-bill?from=#{doc.id}") |> html_response(200)

      refute html =~ "data-business-id"
    end

    test "somebody else's document is ignored", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      doc = earlier(user_scope_fixture())

      html = conn |> get(~p"/fuel-bill?from=#{doc.id}") |> html_response(200)

      assert html =~ "Sunrise Fuel Station"
      refute html =~ "Edited Station"
    end

    test "a document of another template is ignored", %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      doc = earlier(scope, %{slug: "rent-receipt"})

      html = conn |> get(~p"/fuel-bill?from=#{doc.id}") |> html_response(200)

      refute html =~ "Edited Station"
    end

    test "nonsense in from= is ignored", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      assert conn |> get(~p"/fuel-bill?from=abc") |> html_response(200) =~ "Sunrise Fuel Station"
      assert conn |> get(~p"/fuel-bill?from=999999999999") |> html_response(200) =~ "Sunrise"
    end

    test "a visitor can't use it", %{conn: conn} do
      html = conn |> get(~p"/fuel-bill?from=1") |> html_response(200)

      assert html =~ "Sunrise Fuel Station"
    end
  end
end
