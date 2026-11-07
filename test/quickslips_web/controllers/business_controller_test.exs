defmodule QuickSlipsWeb.BusinessControllerTest do
  use QuickSlipsWeb.ConnCase

  import QuickSlips.BusinessesFixtures
  import QuickSlips.SignaturesFixtures
  import QuickSlips.UploadsFixtures

  alias QuickSlips.Businesses

  @details %{
    name: "Sunrise Fuel",
    address: "NH-48, Pune",
    gstin: "29ABCDE1234F1Z5",
    country: "in"
  }

  test "a visitor is told to log in, and nothing is saved", %{conn: conn} do
    conn = post(conn, ~p"/api/businesses", @details)

    assert %{"error" => "log in first"} = json_response(conn, 401)
    assert QuickSlips.Repo.aggregate(Businesses.Business, :count) == 0
  end

  describe "when logged in" do
    setup :register_and_log_in_user

    test "saves the details as a business of the user", %{conn: conn, scope: scope} do
      conn = post(conn, ~p"/api/businesses", @details)

      assert %{"outcome" => "created", "business" => business} = json_response(conn, 200)

      assert %{
               "name" => "Sunrise Fuel",
               "address" => "NH-48, Pune",
               "gstin" => "29ABCDE1234F1Z5",
               "logo_url" => nil,
               "signature_id" => nil
             } = business

      assert [%{id: id}] = Businesses.list_businesses(scope)
      assert business["id"] == id
    end

    test "updates the business that has this name, and keeps its pictures", %{
      conn: conn,
      user: user,
      scope: scope
    } do
      logo = stored_image(user.id)
      signature = signature_fixture(scope)

      existing =
        business_fixture(scope, %{name: "sunrise fuel", signature_id: signature.id}, %{
          logo_path: logo
        })

      conn = post(conn, ~p"/api/businesses", %{@details | address: "A new address"})

      assert %{"outcome" => "updated", "business" => business} = json_response(conn, 200)
      assert business["id"] == existing.id
      assert business["address"] == "A new address"
      assert business["logo_url"] == "/uploads/#{logo}"
      assert business["signature_id"] == signature.id
      assert Businesses.count_businesses(scope) == 1
    end

    test "says name_blank when there is no name", %{conn: conn, scope: scope} do
      for name <- ["", "   ", nil] do
        conn = post(conn, ~p"/api/businesses", %{@details | name: name})
        assert %{"code" => "name_blank"} = json_response(conn, 422)
      end

      assert Businesses.count_businesses(scope) == 0
    end

    test "checks the registration number the way the country of the bill does", %{conn: conn} do
      nif = %{@details | gstin: "b12345678", country: "es"}

      assert %{"outcome" => "created", "business" => %{"gstin" => "B12345678"}} =
               conn |> post(~p"/api/businesses", nif) |> json_response(200)

      # The same number is not a GSTIN, and the answer says what the country calls it.
      conn = post(conn, ~p"/api/businesses", %{nif | country: "in", name: "Other shop"})

      assert %{"code" => "tax_id_invalid", "label" => "GSTIN"} = json_response(conn, 422)
    end

    test "a country with no shape to check lets the number through", %{conn: conn} do
      conn = post(conn, ~p"/api/businesses", %{@details | gstin: "anything goes", country: "zz"})

      assert %{"business" => %{"gstin" => "ANYTHING GOES"}} = json_response(conn, 200)
    end

    test "the address and the number may be left out", %{conn: conn} do
      conn = post(conn, ~p"/api/businesses", %{name: "Just a name", country: "in"})

      assert %{"business" => %{"address" => nil, "gstin" => nil}} = json_response(conn, 200)
    end

    test "never saves a logo or an owner sent along", %{conn: conn, scope: scope} do
      other = QuickSlips.AccountsFixtures.user_scope_fixture()
      params = Map.merge(@details, %{logo_path: "1/stolen.png", user_id: other.user.id})

      assert %{"business" => %{"logo_url" => nil}} =
               conn |> post(~p"/api/businesses", params) |> json_response(200)

      assert [%{user_id: user_id, logo_path: nil}] = Businesses.list_businesses(scope)
      assert user_id == scope.user.id
      assert Businesses.list_businesses(other) == []
    end
  end
end
