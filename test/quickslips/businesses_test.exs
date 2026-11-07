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
    import QuickSlips.SignaturesFixtures
    import QuickSlips.UploadsFixtures

    @valid_attrs %{name: "some name", address: "some address", gstin: "29ABCDE1234F1Z5"}

    test "create_business/3 keeps the stored logo path" do
      scope = user_scope_fixture()
      logo = stored_image(scope.user.id)

      assert {:ok, %Business{logo_path: ^logo, signature_id: nil}} =
               Businesses.create_business(scope, @valid_attrs, %{logo_path: logo})
    end

    test "the logo path can't come from the form" do
      scope = user_scope_fixture()
      attrs = Map.merge(@valid_attrs, %{logo_path: "1/stolen.png"})

      assert {:ok, %Business{logo_path: nil}} = Businesses.create_business(scope, attrs)
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

    test "remove_image/3 clears the logo and deletes the file" do
      scope = user_scope_fixture()
      logo = stored_image(scope.user.id)
      business = business_fixture(scope, %{}, %{logo_path: logo})

      assert {:ok, %Business{logo_path: nil}} = Businesses.remove_image(scope, business, :logo)

      refute File.exists?(Uploads.path(logo))
    end

    test "remove_image/3 on somebody else's business raises" do
      business = business_fixture(user_scope_fixture())

      assert_raise MatchError, fn ->
        Businesses.remove_image(user_scope_fixture(), business, :logo)
      end
    end

    test "delete_business/2 deletes the logo, and keeps the signatures of the user" do
      scope = user_scope_fixture()
      logo = stored_image(scope.user.id)
      signature = signature_fixture(scope)
      business = business_fixture(scope, %{signature_id: signature.id}, %{logo_path: logo})

      assert {:ok, _} = Businesses.delete_business(scope, business)

      refute File.exists?(Uploads.path(logo))
      assert File.exists?(Uploads.path(signature.path))
      assert QuickSlips.Signatures.get_signature(scope, signature.id)
    end

    test "render_assets/2 names the pictures and says where their files are" do
      scope = user_scope_fixture()
      logo = stored_image(scope.user.id)
      signature = signature_fixture(scope, %{}, jpg_bytes())
      business = business_fixture(scope, %{}, %{logo_path: logo})

      assert %{
               data: %{"logo" => "logo.png", "signature" => "signature.jpg"},
               files: %{"logo.png" => logo_file, "signature.jpg" => signature_file}
             } = Businesses.render_assets(business, signature)

      assert logo_file == Uploads.path(logo)
      assert signature_file == Uploads.path(signature.path)
    end

    test "render_assets/2 draws the signature that is given, not the default of the business" do
      scope = user_scope_fixture()
      default = signature_fixture(scope, %{name: "Default"})
      other = signature_fixture(scope, %{name: "Other"}, jpg_bytes())
      business = business_fixture(scope, %{signature_id: default.id})

      assert %{data: %{"signature" => "signature.jpg"}} =
               Businesses.render_assets(business, other)

      assert %{data: data} = Businesses.render_assets(business, nil)
      assert data == %{}
    end

    test "render_assets/2 leaves out a picture that is not there" do
      scope = user_scope_fixture()
      logo = stored_image(scope.user.id)
      signature = signature_fixture(scope)
      File.rm!(Uploads.path(signature.path))

      business = business_fixture(scope, %{}, %{logo_path: logo})

      assert %{data: data, files: files} = Businesses.render_assets(business, signature)
      assert data == %{"logo" => "logo.png"}
      assert Map.keys(files) == ["logo.png"]

      assert %{data: %{}, files: %{}} = Businesses.render_assets(business_fixture(scope))
      assert %{data: %{}, files: %{}} = Businesses.render_assets(nil)
    end

    test "render_assets/2 needs no business to draw a signature" do
      scope = user_scope_fixture()
      signature = signature_fixture(scope)

      assert %{data: %{"signature" => "signature.png"}} = Businesses.render_assets(nil, signature)
    end
  end

  describe "the default signature" do
    alias QuickSlips.Businesses.Business

    import QuickSlips.AccountsFixtures, only: [user_scope_fixture: 0]
    import QuickSlips.BusinessesFixtures
    import QuickSlips.SignaturesFixtures

    test "is one of the user's signatures" do
      scope = user_scope_fixture()
      signature = signature_fixture(scope)

      assert {:ok, %Business{signature_id: id}} =
               Businesses.create_business(scope, %{name: "Shop", signature_id: signature.id})

      assert id == signature.id
    end

    test "can't be somebody else's" do
      scope = user_scope_fixture()
      theirs = signature_fixture(user_scope_fixture())

      assert {:error, changeset} =
               Businesses.create_business(scope, %{name: "Shop", signature_id: theirs.id})

      assert %{signature_id: ["is not one of your signatures"]} = errors_on(changeset)

      business = business_fixture(scope)

      assert {:error, changeset} =
               Businesses.update_business(scope, business, %{signature_id: theirs.id})

      assert %{signature_id: ["is not one of your signatures"]} = errors_on(changeset)

      assert Businesses.change_business(scope, business, %{signature_id: theirs.id}).valid? ==
               false
    end

    test "can be taken away again" do
      scope = user_scope_fixture()
      signature = signature_fixture(scope)
      business = business_fixture(scope, %{signature_id: signature.id})

      assert {:ok, %Business{signature_id: nil}} =
               Businesses.update_business(scope, business, %{signature_id: ""})
    end
  end

  describe "save_details/3" do
    alias QuickSlips.Businesses.Business

    import QuickSlips.AccountsFixtures, only: [user_scope_fixture: 0]
    import QuickSlips.BusinessesFixtures
    import QuickSlips.SignaturesFixtures

    @details %{"name" => "Sunrise Fuel", "address" => "NH-48, Pune", "gstin" => "29ABCDE1234F1Z5"}

    test "makes a business for a name that is new" do
      scope = user_scope_fixture()

      assert {:ok, %Business{name: "Sunrise Fuel", address: "NH-48, Pune"}, :created} =
               Businesses.save_details(scope, @details)

      assert Businesses.count_businesses(scope) == 1
    end

    test "updates the business of that name (capitals do not count), and leaves its pictures" do
      scope = user_scope_fixture()
      signature = signature_fixture(scope)
      existing = business_fixture(scope, %{name: "SUNRISE fuel", signature_id: signature.id})

      assert {:ok,
              %Business{id: id, name: "Sunrise Fuel", address: "NH-48, Pune", signature_id: sid},
              :updated} = Businesses.save_details(scope, @details)

      assert id == existing.id
      assert sid == signature.id
      assert Businesses.count_businesses(scope) == 1
    end

    test "never touches the businesses of somebody else" do
      scope = user_scope_fixture()
      other = user_scope_fixture()
      business_fixture(other, %{name: "Sunrise Fuel", address: "Theirs"})

      assert {:ok, _business, :created} = Businesses.save_details(scope, @details)
      assert [%Business{address: "Theirs"}] = Businesses.list_businesses(other)
    end

    test "ignores everything but the name, the address and the registration number" do
      scope = user_scope_fixture()
      stolen = Map.merge(@details, %{"logo_path" => "1/stolen.png", "user_id" => 1})

      assert {:ok, %Business{logo_path: nil} = business, :created} =
               Businesses.save_details(scope, stolen)

      assert business.user_id == scope.user.id
    end

    test "needs a name" do
      scope = user_scope_fixture()

      assert {:error, changeset} =
               Businesses.save_details(scope, %{"name" => "  ", "address" => "x"})

      assert %{name: ["can't be blank"]} = errors_on(changeset)

      assert {:error, _} = Businesses.save_details(scope, %{"address" => "No name at all"})
    end

    test "checks the registration number as a GSTIN unless told what the country's looks like" do
      scope = user_scope_fixture()
      nif = Map.put(@details, "gstin", "b12345678")

      assert {:error, changeset} = Businesses.save_details(scope, nif)
      assert %{gstin: ["is not a valid GSTIN (15 characters)"]} = errors_on(changeset)

      spain = ~r/^[ABCDEFGHJNPQRSUVW][0-9]{7}[0-9A-J]$/

      assert {:ok, %Business{gstin: "B12345678"}, :created} =
               Businesses.save_details(scope, nif, tax_id: {spain, "NIF"})

      assert {:error, changeset} =
               Businesses.save_details(scope, %{nif | "gstin" => "nope", "name" => "Other"},
                 tax_id: {spain, "NIF"}
               )

      assert %{gstin: ["is not a valid NIF"]} = errors_on(changeset)
    end

    test "lets any number through for a country with no shape to check" do
      scope = user_scope_fixture()

      assert {:ok, %Business{gstin: "ANYTHING 1"}, :created} =
               Businesses.save_details(scope, %{@details | "gstin" => "anything 1"},
                 tax_id: {nil, "registration number"}
               )
    end
  end
end
