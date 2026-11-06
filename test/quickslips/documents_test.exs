defmodule QuickSlips.DocumentsTest do
  use QuickSlips.DataCase

  alias QuickSlips.Documents

  describe "documents" do
    alias QuickSlips.Documents.Document

    import QuickSlips.AccountsFixtures, only: [user_scope_fixture: 0]
    import QuickSlips.DocumentsFixtures

    @invalid_attrs %{data: nil, title: nil, template: nil, slug: nil}

    test "list_documents/1 returns all scoped documents" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      document = document_fixture(scope)
      other_document = document_fixture(other_scope)
      assert Documents.list_documents(scope) == [document]
      assert Documents.list_documents(other_scope) == [other_document]
    end

    test "get_document!/2 returns the document with given id" do
      scope = user_scope_fixture()
      document = document_fixture(scope)
      other_scope = user_scope_fixture()
      assert Documents.get_document!(scope, document.id) == document

      assert_raise Ecto.NoResultsError, fn ->
        Documents.get_document!(other_scope, document.id)
      end
    end

    test "create_document/2 with valid data creates a document" do
      valid_attrs = %{
        data: %{},
        title: "some title",
        template: "some template",
        slug: "fuel-bill"
      }

      scope = user_scope_fixture()

      assert {:ok, %Document{} = document} = Documents.create_document(scope, valid_attrs)
      assert document.data == %{}
      assert document.title == "some title"
      assert document.template == "some template"
      assert document.slug == "fuel-bill"
      assert document.user_id == scope.user.id
    end

    test "create_document/2 keeps the language and the options, and defaults to English" do
      scope = user_scope_fixture()
      attrs = %{data: %{}, title: "t", template: "t1", slug: "fuel-bill"}

      assert {:ok, %Document{language: "en", options: %{}}} =
               Documents.create_document(scope, attrs)

      assert {:ok, %Document{language: "hi", options: %{"country" => "in", "currency" => "INR"}}} =
               Documents.create_document(
                 scope,
                 Map.merge(attrs, %{
                   language: "hi",
                   options: %{"country" => "in", "currency" => "INR"}
                 })
               )
    end

    test "create_document/2 refuses a language the site does not have" do
      scope = user_scope_fixture()
      attrs = %{data: %{}, title: "t", template: "t1", slug: "fuel-bill", language: "xx"}

      assert {:error, %Ecto.Changeset{errors: [language: {"is invalid", _}]}} =
               Documents.create_document(scope, attrs)
    end

    test "create_document/2 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      assert {:error, %Ecto.Changeset{}} = Documents.create_document(scope, @invalid_attrs)
    end

    test "update_document/3 with valid data updates the document" do
      scope = user_scope_fixture()
      document = document_fixture(scope)

      update_attrs = %{
        data: %{},
        title: "some updated title",
        template: "some updated template",
        slug: "some updated slug"
      }

      assert {:ok, %Document{} = document} =
               Documents.update_document(scope, document, update_attrs)

      assert document.data == %{}
      assert document.title == "some updated title"
      assert document.template == "some updated template"
      assert document.slug == "some updated slug"
    end

    test "update_document/3 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      document = document_fixture(scope)

      assert_raise MatchError, fn ->
        Documents.update_document(other_scope, document, %{})
      end
    end

    test "update_document/3 with invalid data returns error changeset" do
      scope = user_scope_fixture()
      document = document_fixture(scope)

      assert {:error, %Ecto.Changeset{}} =
               Documents.update_document(scope, document, @invalid_attrs)

      assert document == Documents.get_document!(scope, document.id)
    end

    test "delete_document/2 deletes the document" do
      scope = user_scope_fixture()
      document = document_fixture(scope)
      assert {:ok, %Document{}} = Documents.delete_document(scope, document)
      assert_raise Ecto.NoResultsError, fn -> Documents.get_document!(scope, document.id) end
    end

    test "delete_document/2 with invalid scope raises" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      document = document_fixture(scope)
      assert_raise MatchError, fn -> Documents.delete_document(other_scope, document) end
    end

    test "change_document/2 returns a document changeset" do
      scope = user_scope_fixture()
      document = document_fixture(scope)
      assert %Ecto.Changeset{} = Documents.change_document(scope, document)
    end
  end

  describe "history" do
    alias QuickSlips.Documents.Document

    import QuickSlips.AccountsFixtures, only: [user_scope_fixture: 0]
    import QuickSlips.BusinessesFixtures
    import QuickSlips.DocumentsFixtures

    test "list_documents/2 puts the newest first" do
      scope = user_scope_fixture()
      first = document_fixture(scope, %{title: "first"})
      second = document_fixture(scope, %{title: "second"})
      third = document_fixture(scope, %{title: "third"})

      assert Enum.map(Documents.list_documents(scope), & &1.id) == [third.id, second.id, first.id]
    end

    test "list_documents/2 can search the titles and limit the list" do
      scope = user_scope_fixture()
      document_fixture(scope, %{title: "Fuel Bill · Sunrise Station"})
      document_fixture(scope, %{title: "Rent Receipt · Ramesh"})
      document_fixture(scope, %{title: "Fuel Bill · Kaveri Point"})

      assert ["Fuel Bill · Kaveri Point", "Fuel Bill · Sunrise Station"] =
               Documents.list_documents(scope, search: "fuel") |> Enum.map(& &1.title)

      assert [%{title: "Fuel Bill · Kaveri Point"}] = Documents.list_documents(scope, limit: 1)
      assert length(Documents.list_documents(scope, search: "")) == 3
    end

    test "a search for % or _ means those characters, not any text" do
      scope = user_scope_fixture()
      document_fixture(scope, %{title: "50% off"})
      document_fixture(scope, %{title: "other"})

      assert [%{title: "50% off"}] = Documents.list_documents(scope, search: "%")
      assert [] = Documents.list_documents(scope, search: "_")
    end

    test "create_document/3 remembers the business, and the form can't choose it" do
      scope = user_scope_fixture()
      business = business_fixture(scope)

      assert {:ok, %Document{business_id: business_id}} =
               Documents.create_document(
                 scope,
                 %{slug: "fuel-bill", template: "t1", title: "t", data: %{}, business_id: 999},
                 business
               )

      assert business_id == business.id

      assert {:ok, %Document{business_id: nil}} =
               Documents.create_document(scope, %{
                 slug: "fuel-bill",
                 template: "t1",
                 title: "t",
                 data: %{},
                 business_id: 999
               })
    end

    test "a deleted business only takes the pictures away, not the document" do
      scope = user_scope_fixture()
      business = business_fixture(scope)
      document = document_fixture(scope, %{}, business)

      {:ok, _} = QuickSlips.Businesses.delete_business(scope, business)

      assert %Document{business_id: nil} = Documents.get_document!(scope, document.id)
    end

    test "only the 200 newest documents of a user are kept" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      mine = for n <- 1..201, do: document_fixture(scope, %{title: "doc #{n}"})
      document_fixture(other_scope)

      kept = Documents.list_documents(scope)

      assert length(kept) == 200
      refute Enum.any?(kept, &(&1.id == hd(mine).id))
      assert length(Documents.list_documents(other_scope)) == 1
    end

    test "count_this_month/1 counts this month's documents of the user" do
      scope = user_scope_fixture()
      other_scope = user_scope_fixture()
      document_fixture(scope)
      document_fixture(scope)
      old = document_fixture(scope)
      document_fixture(other_scope)

      last_month = DateTime.utc_now() |> DateTime.add(-40 * 86_400) |> DateTime.truncate(:second)

      QuickSlips.Repo.update_all(
        from(d in Document, where: d.id == ^old.id),
        set: [inserted_at: last_month]
      )

      assert Documents.count_this_month(scope) == 2
    end

    test "get_document_for_template/3 only gives the user's own document of that template" do
      scope = user_scope_fixture()
      document = document_fixture(scope)

      assert %Document{} = Documents.get_document_for_template(scope, document.id, "fuel-bill")

      assert %Document{} =
               Documents.get_document_for_template(scope, "#{document.id}", "fuel-bill")

      assert nil == Documents.get_document_for_template(scope, document.id, "rent-receipt")

      assert nil ==
               Documents.get_document_for_template(user_scope_fixture(), document.id, "fuel-bill")

      assert nil == Documents.get_document_for_template(scope, "not a number", "fuel-bill")
      assert nil == Documents.get_document_for_template(scope, nil, "fuel-bill")
    end
  end

  describe "build_title/2" do
    @fuel_bill %{
      "title" => "Fuel Bill Generator",
      "number_field" => "bill_number",
      "fields" => [
        %{"key" => "station_name", "type" => "text", "prefill" => "business.name"},
        %{"key" => "bill_number", "type" => "text"},
        %{"key" => "date", "type" => "date"}
      ]
    }

    test "has the template, the number, the seller and the date" do
      data = %{
        "station_name" => "Sunrise Fuel Station",
        "bill_number" => "FB-1",
        "date" => "2026-10-12"
      }

      assert Documents.build_title(@fuel_bill, data) ==
               "Fuel Bill · FB-1 · Sunrise Fuel Station · 12 Oct 2026"
    end

    test "leaves out what the data does not have" do
      assert Documents.build_title(@fuel_bill, %{"bill_number" => "FB-1"}) == "Fuel Bill · FB-1"
      assert Documents.build_title(@fuel_bill, %{}) == "Fuel Bill"

      assert Documents.build_title(@fuel_bill, %{"date" => "2026-10-12"}) ==
               "Fuel Bill · 12 Oct 2026"
    end

    test "uses the name and the months of the language" do
      schema = Map.put(@fuel_bill, "name", "पेट्रोल बिल")
      months = ~w(जन. फ़र. मार्च अप्रैल मई जून जुलाई अग. सित. अक्टू. नव. दिस.)

      data = %{"bill_number" => "FB-1", "date" => "2026-10-05"}

      assert Documents.build_title(schema, data, months) == "पेट्रोल बिल · FB-1 · 05 अक्टू. 2026"
      # With no months given, English ones.
      assert Documents.build_title(schema, data) == "पेट्रोल बिल · FB-1 · 05 Oct 2026"
    end

    test "falls back to a month when there is no date" do
      schema = %{
        "title" => "Rent Receipt Generator",
        "fields" => [%{"key" => "month", "type" => "month"}]
      }

      assert Documents.build_title(schema, %{"month" => "2026-10"}) == "Rent Receipt · Oct 2026"
    end

    test "keeps a title that does not end in Generator, and a date it can't read" do
      schema = %{"title" => "Taxi Receipt", "fields" => [%{"key" => "date", "type" => "date"}]}

      assert Documents.build_title(schema, %{"date" => "tomorrow"}) == "Taxi Receipt · tomorrow"
    end
  end
end
