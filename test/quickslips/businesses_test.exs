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

  describe "images" do
    alias QuickSlips.Businesses.Business
    alias QuickSlips.Uploads

    import QuickSlips.AccountsFixtures, only: [user_scope_fixture: 0]
    import QuickSlips.BusinessesFixtures
    import QuickSlips.UploadsFixtures

    @valid_attrs %{name: "some name", address: "some address", gstin: "29ABCDE1234F1Z5"}

    test "create_business/3 keeps the stored paths" do
      scope = user_scope_fixture()
      logo = stored_image(scope.user.id)

      assert {:ok, %Business{logo_path: ^logo, signature_path: nil}} =
               Businesses.create_business(scope, @valid_attrs, %{logo_path: logo})
    end

    test "the paths can't come from the form" do
      scope = user_scope_fixture()

      attrs =
        Map.merge(@valid_attrs, %{logo_path: "1/stolen.png", signature_path: "1/stolen.png"})

      assert {:ok, %Business{logo_path: nil, signature_path: nil}} =
               Businesses.create_business(scope, attrs)
    end

    test "address and GSTIN are optional, the name is not" do
      scope = user_scope_fixture()

      assert {:ok, %Business{address: nil, gstin: nil}} =
               Businesses.create_business(scope, %{name: "Just a name"})

      assert {:error, changeset} = Businesses.create_business(scope, %{name: ""})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "update_business/4 with a new image deletes the old file" do
      scope = user_scope_fixture()
      old = stored_image(scope.user.id)
      new = stored_image(scope.user.id, jpg_bytes())
      business = business_fixture(scope, %{}, %{logo_path: old})

      assert {:ok, %Business{logo_path: ^new}} =
               Businesses.update_business(scope, business, %{}, %{logo_path: new})

      refute File.exists?(Uploads.path(old))
      assert File.exists?(Uploads.path(new))
    end

    test "update_business/3 without images keeps the ones it has" do
      scope = user_scope_fixture()
      logo = stored_image(scope.user.id)
      business = business_fixture(scope, %{}, %{logo_path: logo})

      assert {:ok, %Business{logo_path: ^logo}} =
               Businesses.update_business(scope, business, %{name: "New name"})

      assert File.exists?(Uploads.path(logo))
    end

    test "remove_image/3 clears the column and deletes the file" do
      scope = user_scope_fixture()
      logo = stored_image(scope.user.id)
      signature = stored_image(scope.user.id)
      business = business_fixture(scope, %{}, %{logo_path: logo, signature_path: signature})

      assert {:ok, %Business{logo_path: nil, signature_path: ^signature}} =
               Businesses.remove_image(scope, business, :logo)

      refute File.exists?(Uploads.path(logo))
      assert File.exists?(Uploads.path(signature))
    end

    test "remove_image/3 on somebody else's business raises" do
      business = business_fixture(user_scope_fixture())

      assert_raise MatchError, fn ->
        Businesses.remove_image(user_scope_fixture(), business, :logo)
      end
    end

    test "delete_business/2 deletes the pictures too" do
      scope = user_scope_fixture()
      logo = stored_image(scope.user.id)
      signature = stored_image(scope.user.id, jpg_bytes())
      business = business_fixture(scope, %{}, %{logo_path: logo, signature_path: signature})

      assert {:ok, _} = Businesses.delete_business(scope, business)

      refute File.exists?(Uploads.path(logo))
      refute File.exists?(Uploads.path(signature))
    end

    test "render_assets/1 names the pictures and says where their files are" do
      scope = user_scope_fixture()
      logo = stored_image(scope.user.id)
      signature = stored_image(scope.user.id, jpg_bytes())
      business = business_fixture(scope, %{}, %{logo_path: logo, signature_path: signature})

      assert %{
               data: %{"logo" => "logo.png", "signature" => "signature.jpg"},
               files: %{"logo.png" => logo_file, "signature.jpg" => signature_file}
             } = Businesses.render_assets(business)

      assert logo_file == Uploads.path(logo)
      assert signature_file == Uploads.path(signature)
    end

    test "render_assets/1 leaves out a picture that is not there" do
      scope = user_scope_fixture()
      logo = stored_image(scope.user.id)

      business =
        business_fixture(scope, %{}, %{
          logo_path: logo,
          signature_path: "#{scope.user.id}/0000000000000000.png"
        })

      assert %{data: data, files: files} = Businesses.render_assets(business)
      assert data == %{"logo" => "logo.png"}
      assert Map.keys(files) == ["logo.png"]

      assert %{data: %{}, files: %{}} = Businesses.render_assets(business_fixture(scope))
    end
  end
end
