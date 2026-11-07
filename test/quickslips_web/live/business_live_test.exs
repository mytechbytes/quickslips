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

  describe "Form pictures" do
    import QuickSlips.SignaturesFixtures
    import QuickSlips.UploadsFixtures

    alias QuickSlips.Businesses
    alias QuickSlips.Uploads

    setup %{user: user} do
      on_exit(fn -> File.rm_rf(Path.join(Uploads.root(), Integer.to_string(user.id))) end)
    end

    defp stored_files(user),
      do: Path.wildcard(Path.join([Uploads.root(), Integer.to_string(user.id), "*"]))

    defp choose(live, upload, name, content, type) do
      live
      |> file_input("#business-form", upload, [%{name: name, content: content, type: type}])
      |> render_upload(name)
    end

    test "saves a new business with a logo and a default signature", %{
      conn: conn,
      user: user,
      scope: scope
    } do
      signature = signature_fixture(scope, %{name: "Owner"})
      {:ok, form_live, _html} = live(conn, ~p"/businesses/new")

      choose(form_live, :logo, "logo.png", png_bytes(), "image/png")

      assert {:ok, _index_live, html} =
               form_live
               |> form("#business-form",
                 business: Map.put(@create_attrs, :signature_id, signature.id)
               )
               |> render_submit()
               |> follow_redirect(conn, ~p"/businesses")

      assert html =~ "Business created successfully"

      [business] = Businesses.list_businesses(scope)
      assert business.logo_path =~ ~r/^#{user.id}\/[a-f0-9]{16}\.png$/
      assert business.signature_id == signature.id
      assert File.read!(Uploads.path(business.logo_path)) == png_bytes()
    end

    test "the form has no upload for a signature: it is chosen from the library", %{
      conn: conn,
      scope: scope
    } do
      signature_fixture(scope, %{name: "Owner"})
      signature_fixture(scope, %{name: "Manager"})
      {:ok, form_live, _html} = live(conn, ~p"/businesses/new")

      refute has_element?(form_live, "#signature-field")
      assert has_element?(form_live, "#logo-field")

      assert has_element?(form_live, "#business_signature_id option", "No default signature")
      assert has_element?(form_live, "#business_signature_id option", "Owner")
      assert has_element?(form_live, "#business_signature_id option", "Manager")
      refute has_element?(form_live, "#no-signatures")
    end

    test "points to the Signatures page when there are none yet", %{conn: conn} do
      {:ok, form_live, _html} = live(conn, ~p"/businesses/new")

      assert has_element?(form_live, "#no-signatures a[href='/signatures']")
    end

    test "somebody else's signature can't be the default", %{conn: conn, scope: scope} do
      theirs = signature_fixture(QuickSlips.AccountsFixtures.user_scope_fixture())
      {:ok, form_live, _html} = live(conn, ~p"/businesses/new")

      html =
        render_submit(form_live, "save", %{
          "business" =>
            Map.put(
              Map.new(@create_attrs, fn {k, v} -> {Atom.to_string(k), v} end),
              "signature_id",
              theirs.id
            )
        })

      assert html =~ "is not one of your signatures"
      assert Businesses.list_businesses(scope) == []
    end

    test "the default signature of a saved business is chosen in the select", %{
      conn: conn,
      scope: scope
    } do
      signature = signature_fixture(scope, %{name: "Owner"})
      business = business_fixture(scope, %{signature_id: signature.id})

      {:ok, form_live, _html} = live(conn, ~p"/businesses/#{business}/edit")

      assert has_element?(
               form_live,
               ~s(#business_signature_id option[selected][value="#{signature.id}"])
             )
    end

    test "a file that is not really a picture is turned down, and nothing is saved", %{
      conn: conn,
      scope: scope
    } do
      {:ok, form_live, _html} = live(conn, ~p"/businesses/new")

      choose(form_live, :logo, "logo.png", "this is only text", "image/png")

      html = form_live |> form("#business-form", business: @create_attrs) |> render_submit()

      assert html =~ "The logo is not a real PNG or JPG picture."
      assert Businesses.list_businesses(scope) == []
    end

    test "a file over 1 MB is refused", %{conn: conn} do
      {:ok, form_live, _html} = live(conn, ~p"/businesses/new")

      big = :binary.copy("a", 1_000_001)

      logo =
        file_input(form_live, "#business-form", :logo, [
          %{name: "big.png", content: big, type: "image/png"}
        ])

      assert {:error, [[_ref, :too_large]]} = render_upload(logo, "big.png")
      assert render(form_live) =~ "This file is too big. The limit is 1 MB."
    end

    test "a wrong file type is refused", %{conn: conn} do
      {:ok, form_live, _html} = live(conn, ~p"/businesses/new")

      logo =
        file_input(form_live, "#business-form", :logo, [
          %{name: "logo.svg", content: "<svg></svg>", type: "image/svg+xml"}
        ])

      assert {:error, [[_ref, :not_accepted]]} = render_upload(logo, "logo.svg")
      assert render(form_live) =~ "Only PNG and JPG files can be used."
    end

    test "text fields with errors keep the chosen file and store nothing yet", %{
      conn: conn,
      user: user
    } do
      {:ok, form_live, _html} = live(conn, ~p"/businesses/new")

      choose(form_live, :logo, "logo.png", png_bytes(), "image/png")

      html = form_live |> form("#business-form", business: @invalid_attrs) |> render_submit()

      assert html =~ "can&#39;t be blank"
      assert html =~ "logo.png"
      assert stored_files(user) == []
    end

    test "a new picture replaces the saved one and its file is deleted", %{
      conn: conn,
      user: user,
      scope: scope
    } do
      old = stored_image(user.id)
      business = business_fixture(scope, %{}, %{logo_path: old})
      {:ok, form_live, html} = live(conn, ~p"/businesses/#{business}/edit")

      assert html =~ ~s(src="/uploads/#{old}")

      choose(form_live, :logo, "new.jpg", jpg_bytes(), "image/jpeg")

      assert {:ok, _index_live, _html} =
               form_live
               |> form("#business-form", business: %{name: "Renamed"})
               |> render_submit()
               |> follow_redirect(conn, ~p"/businesses")

      updated = Businesses.get_business!(scope, business.id)
      assert updated.logo_path =~ ~r/\.jpg$/
      refute File.exists?(Uploads.path(old))
      assert File.exists?(Uploads.path(updated.logo_path))
    end

    test "the saved logo can be removed, and the default signature stays", %{
      conn: conn,
      user: user,
      scope: scope
    } do
      logo = stored_image(user.id)
      signature = signature_fixture(scope)
      business = business_fixture(scope, %{signature_id: signature.id}, %{logo_path: logo})
      {:ok, form_live, _html} = live(conn, ~p"/businesses/#{business}/edit")

      html = form_live |> element("#logo-field button", "Remove the saved logo") |> render_click()

      refute html =~ ~s(src="/uploads/#{logo}")

      assert %{logo_path: nil, signature_id: signature_id} =
               Businesses.get_business!(scope, business.id)

      assert signature_id == signature.id
      refute File.exists?(Uploads.path(logo))
      assert File.exists?(Uploads.path(signature.path))
    end

    test "the show page draws the logo and the default signature", %{
      conn: conn,
      user: user,
      scope: scope
    } do
      logo = stored_image(user.id)
      signature = signature_fixture(scope, %{name: "Owner"})
      business = business_fixture(scope, %{signature_id: signature.id}, %{logo_path: logo})

      {:ok, show_live, _html} = live(conn, ~p"/businesses/#{business}")

      assert has_element?(show_live, ~s(#business-logo[src="/uploads/#{logo}"]))
      assert has_element?(show_live, ~s(#business-signature[src="/uploads/#{signature.path}"]))
    end

    test "the show page has no signature to draw when there is no default", %{
      conn: conn,
      user: user,
      scope: scope
    } do
      business = business_fixture(scope, %{}, %{logo_path: stored_image(user.id)})

      {:ok, show_live, _html} = live(conn, ~p"/businesses/#{business}")

      refute has_element?(show_live, "#business-signature")
    end

    test "deleting a business deletes its pictures", %{conn: conn, user: user, scope: scope} do
      logo = stored_image(user.id)
      business = business_fixture(scope, %{}, %{logo_path: logo})
      {:ok, index_live, _html} = live(conn, ~p"/businesses")

      index_live |> element("#businesses-#{business.id} a", "Delete") |> render_click()

      refute File.exists?(Uploads.path(logo))
    end
  end
end
