defmodule QuickSlipsWeb.HistoryLiveTest do
  use QuickSlipsWeb.ConnCase

  import Phoenix.LiveViewTest
  import QuickSlips.AccountsFixtures
  import QuickSlips.DocumentsFixtures

  alias QuickSlips.Documents

  test "visitors are sent to the log-in page", %{conn: conn} do
    assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/history")
    assert path == ~p"/users/log-in"
  end

  describe "when logged in" do
    setup :register_and_log_in_user

    # The ids of the rows, top to bottom.
    defp row_ids(view) do
      view
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("#documents li")
      |> LazyHTML.attribute("id")
    end

    test "says so when there are no documents yet", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/history")

      assert has_element?(view, "#history-empty-new-document")
      assert row_ids(view) == []
    end

    test "lists the user's documents, newest first, and nobody else's", %{
      conn: conn,
      scope: scope
    } do
      older = document_fixture(scope, %{title: "Fuel Bill · Older Station"})

      newer =
        document_fixture(scope, %{title: "Rent Receipt · Newer Landlord", slug: "rent-receipt"})

      document_fixture(user_scope_fixture(), %{title: "Somebody Else's Bill"})

      {:ok, view, html} = live(conn, ~p"/history")

      assert row_ids(view) == ["documents-#{newer.id}", "documents-#{older.id}"]
      assert html =~ "Newer Landlord"
      refute html =~ "Somebody Else"
      refute has_element?(view, "#history-empty-new-document")
    end

    test "each row can be downloaded again and edited", %{conn: conn, scope: scope} do
      doc = document_fixture(scope, %{slug: "rent-receipt"})
      {:ok, view, _html} = live(conn, ~p"/history")

      assert has_element?(view, ~s(#download-#{doc.id}[href="/history/#{doc.id}/download"]))

      assert has_element?(
               view,
               ~s(#edit-#{doc.id}[href="/en-in/rent-receipt-generator?from=#{doc.id}"])
             )
    end

    test "the edit link opens the page of the language the document was made in", %{
      conn: conn,
      scope: scope
    } do
      hindi = document_fixture(scope, %{language: "hi", options: %{"country" => "in"}})
      spanish = document_fixture(scope, %{language: "es", options: %{"country" => "es"}})
      # A template that has no Spanish page opens in English.
      rent =
        document_fixture(scope, %{
          slug: "courier-receipt",
          language: "es",
          options: %{"country" => "es"}
        })

      {:ok, view, _html} = live(conn, ~p"/history")

      assert has_element?(
               view,
               ~s(#edit-#{hindi.id}[href="/hi-in/fuel-bill-generator?from=#{hindi.id}"])
             )

      assert has_element?(
               view,
               ~s(#edit-#{spanish.id}[href="/es-es/generador-de-factura-de-gasolina?from=#{spanish.id}"])
             )

      assert has_element?(
               view,
               ~s(#edit-#{rent.id}[href="/en-in/courier-receipt-generator?from=#{rent.id}"])
             )
    end

    test "a search keeps the documents whose title matches", %{conn: conn, scope: scope} do
      fuel = document_fixture(scope, %{title: "Fuel Bill · Sunrise"})
      document_fixture(scope, %{title: "Rent Receipt · Ramesh"})
      {:ok, view, _html} = live(conn, ~p"/history")

      view |> form("#history-search-form", q: "fuel") |> render_change()
      assert row_ids(view) == ["documents-#{fuel.id}"]

      view |> form("#history-search-form", q: "nothing like this") |> render_change()
      assert row_ids(view) == []
      assert has_element?(view, "#history-no-match")
      refute has_element?(view, "#history-empty-new-document")

      view |> form("#history-search-form", q: "") |> render_change()
      assert length(row_ids(view)) == 2
    end

    test "deleting removes the document, and the last one brings the empty state back", %{
      conn: conn,
      scope: scope
    } do
      doc = document_fixture(scope)
      {:ok, view, _html} = live(conn, ~p"/history")

      view |> element("#delete-#{doc.id}") |> render_click()

      assert row_ids(view) == []
      assert has_element?(view, "#history-empty-new-document")
      assert_raise Ecto.NoResultsError, fn -> Documents.get_document!(scope, doc.id) end
    end

    @tag :capture_log
    test "can't delete somebody else's document", %{conn: conn} do
      other_doc = document_fixture(user_scope_fixture())
      {:ok, view, _html} = live(conn, ~p"/history")
      # A forged event makes the page's process raise, as it should; the test must survive that.
      Process.flag(:trap_exit, true)

      assert catch_exit(render_click(view, "delete", %{"id" => "#{other_doc.id}"}))
      assert QuickSlips.Repo.get(QuickSlips.Documents.Document, other_doc.id)
    end

    test "a document made in another tab shows up", %{conn: conn, scope: scope} do
      {:ok, view, _html} = live(conn, ~p"/history")
      assert row_ids(view) == []

      doc = document_fixture(scope, %{title: "Made elsewhere"})

      assert render(view) =~ "Made elsewhere"
      assert row_ids(view) == ["documents-#{doc.id}"]
    end
  end
end
