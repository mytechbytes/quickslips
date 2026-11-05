defmodule QuickSlips.BusinessesTest do
  use QuickSlips.DataCase

  alias QuickSlips.Businesses

  describe "businesses" do
    alias QuickSlips.Businesses.Business

    import QuickSlips.AccountsFixtures, only: [user_scope_fixture: 0]
    import QuickSlips.BusinessesFixtures

    @invalid_attrs %{name: nil, address: nil, gstin: nil}

    test "list_businesses/1 returns all scoped businesses" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      business = business_fixture(scope)
      other_business = business_fixture(other_scope)
      assert Businesses.list_businesses(scope) == [business]
      assert Businesses.list_businesses(other_scope) == [other_business]
    end

    test "get_business!/2 returns the business with given id" do
      scope = user_scope_fixture()
      business = business_fixture(scope)
      other_scope = user_scope_fixture()
      assert Businesses.get_business!(scope, business.id) == business

      assert_raise Ecto.NoResultsError, fn ->
        Businesses.get_business!(other_scope, business.id)
      end
    end

    test "create_business/2 with valid data creates a business" do
      valid_attrs = %{name: "some name", address: "some address", gstin: "29ABCDE1234F1Z5"}
      scope = user_scope_fixture()

      assert {:ok, %Business{} = business} = Businesses.create_business(scope, valid_attrs)
      assert business.name == "some name"
      assert business.address == "some address"
      assert business.gstin == "29ABCDE1234F1Z5"
      assert business.user_id == scope.user.id
    end

    test "create_business/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Businesses.create_business(scope, @invalid_attrs)
    end

    test "update_business/3 with valid data updates the business" do
      scope = user_scope_fixture()
      business = business_fixture(scope)

      update_attrs = %{
        name: "some updated name",
        address: "some updated address",
        gstin: "29ABCDE1234F1Z5"
      }

      assert {:ok, %Business{} = business} =
               Businesses.update_business(scope, business, update_attrs)

      assert business.name == "some updated name"
      assert business.address == "some updated address"
      assert business.gstin == "29ABCDE1234F1Z5"
    end

    test "update_business/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      business = business_fixture(scope)

      assert_raise MatchError, fn ->
        Businesses.update_business(other_scope, business, %{})
      end
    end

    test "update_business/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      business = business_fixture(scope)

      assert {:error, %Ecto.Changeset{}} =
               Businesses.update_business(scope, business, @invalid_attrs)

      assert business == Businesses.get_business!(scope, business.id)
    end

    test "delete_business/2 deletes the business" do
      scope = user_scope_fixture()
      business = business_fixture(scope)
      assert {:ok, %Business{}} = Businesses.delete_business(scope, business)
      assert_raise Ecto.NoResultsError, fn -> Businesses.get_business!(scope, business.id) end
    end

    test "delete_business/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      business = business_fixture(scope)
      assert_raise MatchError, fn -> Businesses.delete_business(other_scope, business) end
    end

    test "change_business/2 returns a business changeset" do
      scope = user_scope_fixture()
      business = business_fixture(scope)
      assert %Ecto.Changeset{} = Businesses.change_business(scope, business)
    end
  end
end
