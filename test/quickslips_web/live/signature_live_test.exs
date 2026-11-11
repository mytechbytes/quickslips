defmodule QuickSlipsWeb.SignatureLiveTest do
  use QuickSlipsWeb.ConnCase

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import QuickSlips.SignaturesFixtures
  import QuickSlips.UploadsFixtures

  alias QuickSlips.Signatures
  alias QuickSlips.Uploads

  test "visitors are sent to the log-in page", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/signatures")
  end

  describe "when logged in" do
    setup :register_and_log_in_user

    setup %{user: user} do
      on_exit(fn -> File.rm_rf(Path.join(Uploads.root(), Integer.to_string(user.id))) end)
    end

    defp choose(live, name, content, type \\ "image/png") do
      live
      |> file_input("#signature-form", :signature, [%{name: name, content: content, type: type}])
      |> render_upload(name)
    end

    defp stored_files(user),
      do: Path.wildcard(Path.join([Uploads.root(), Integer.to_string(user.id), "*"]))

    test "lists the user's signatures with their pictures, and nobody else's", %{
      conn: conn,
      scope: scope
    } do
      mine = signature_fixture(scope, %{name: "Owner"})

      theirs =
        signature_fixture(QuickSlips.AccountsFixtures.user_scope_fixture(), %{name: "Not mine"})

      {:ok, view, html} = live(conn, ~p"/signatures")

      assert has_element?(view, "#signatures-#{mine.id}", "Owner")
      assert html =~ ~s(src="/uploads/#{mine.path}")
      refute has_element?(view, "#signatures-#{theirs.id}")
      refute has_element?(view, "#no-signatures")
    end

    test "says so when there are none yet", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/signatures")

      assert has_element?(view, "#no-signatures")
      assert has_element?(view, "#signature-form")
    end

    test "is in the menu", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/signatures")

      assert has_element?(view, ~s(#nav-signatures[href="/signatures"]), "Signatures")
    end

    test "saves a signature: the name and the picture", %{conn: conn, user: user, scope: scope} do
      {:ok, view, _html} = live(conn, ~p"/signatures")
      choose(view, "sign.png", png_bytes())

      html =
        view
        |> form("#signature-form", signature: %{name: "Owner", rights: "true"})
        |> render_submit()

      assert html =~ "Signature saved."
      assert [%{name: "Owner", path: path}] = Signatures.list_signatures(scope)
      assert path =~ ~r/^#{user.id}\/[a-f0-9]{16}\.png$/
      assert File.read!(Uploads.path(path)) == png_bytes()
      assert has_element?(view, "#signatures", "Owner")
      refute has_element?(view, "#no-signatures")
      # The form is empty again, ready for the next one.
      refute render(view) =~ "sign.png"
    end

    test "a name is needed, and the chosen file waits", %{conn: conn, user: user, scope: scope} do
      {:ok, view, _html} = live(conn, ~p"/signatures")
      choose(view, "sign.png", png_bytes())

      html =
        view
        |> form("#signature-form", signature: %{name: "  ", rights: "true"})
        |> render_submit()

      assert html =~ "can&#39;t be blank"
      assert html =~ "sign.png"
      assert Signatures.list_signatures(scope) == []
      assert stored_files(user) == []
    end

    test "a name that is taken is told, and the chosen file waits", %{
      conn: conn,
      user: user,
      scope: scope
    } do
      signature_fixture(scope, %{name: "Owner"})
      {:ok, view, _html} = live(conn, ~p"/signatures")
      choose(view, "second.png", png_bytes())

      html =
        view
        |> form("#signature-form", signature: %{name: "owner", rights: "true"})
        |> render_submit()

      assert html =~ "is already used by another of your signatures"
      assert html =~ "second.png"
      assert Signatures.count_signatures(scope) == 1
      assert length(stored_files(user)) == 1

      # With another name, the same file goes through.
      html =
        view
        |> form("#signature-form", signature: %{name: "Manager", rights: "true"})
        |> render_submit()

      assert html =~ "Signature saved."
      assert Signatures.count_signatures(scope) == 2
    end

    test "a picture is needed", %{conn: conn, scope: scope} do
      {:ok, view, _html} = live(conn, ~p"/signatures")

      html =
        view
        |> form("#signature-form", signature: %{name: "Owner", rights: "true"})
        |> render_submit()

      assert html =~ "Choose a picture of the signature first."
      assert Signatures.list_signatures(scope) == []
    end

    test "a file that is not really a picture is turned down", %{
      conn: conn,
      user: user,
      scope: scope
    } do
      {:ok, view, _html} = live(conn, ~p"/signatures")
      choose(view, "sign.png", "this is only text")

      html =
        view
        |> form("#signature-form", signature: %{name: "Owner", rights: "true"})
        |> render_submit()

      assert html =~ "The signature is not a real PNG or JPG picture."
      assert Signatures.list_signatures(scope) == []
      assert stored_files(user) == []
    end

    test "a wrong type and a file over 1 MB are refused at once", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/signatures")

      svg =
        file_input(view, "#signature-form", :signature, [
          %{name: "sign.svg", content: "<svg></svg>", type: "image/svg+xml"}
        ])

      assert {:error, [[_ref, :not_accepted]]} = render_upload(svg, "sign.svg")
      assert render(view) =~ "Only PNG and JPG files can be used."

      {:ok, view, _html} = live(conn, ~p"/signatures")

      big =
        file_input(view, "#signature-form", :signature, [
          %{name: "big.png", content: :binary.copy("a", 1_000_001), type: "image/png"}
        ])

      assert {:error, [[_ref, :too_large]]} = render_upload(big, "big.png")
      assert render(view) =~ "This file is too big. The limit is 1 MB."
    end

    test "a chosen file can be taken back", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/signatures")
      choose(view, "sign.png", png_bytes())
      assert render(view) =~ "sign.png"

      view |> element("#signature-field button", "Remove") |> render_click()

      refute render(view) =~ "sign.png"
    end

    test "deletes a signature and its file", %{conn: conn, scope: scope} do
      signature = signature_fixture(scope, %{name: "Owner"})
      {:ok, view, _html} = live(conn, ~p"/signatures")

      view |> element("#delete-signatures-#{signature.id}") |> render_click()

      refute has_element?(view, "#signatures-#{signature.id}")
      assert Signatures.list_signatures(scope) == []
      refute File.exists?(Uploads.path(signature.path))
      assert has_element?(view, "#no-signatures")
    end

    test "can't delete somebody else's signature", %{conn: conn} do
      theirs = signature_fixture(QuickSlips.AccountsFixtures.user_scope_fixture())
      {:ok, view, _html} = live(conn, ~p"/signatures")
      # The page crashes (a 404 for the request), and the test must outlive it.
      Process.flag(:trap_exit, true)

      capture_log(fn ->
        assert catch_exit(render_click(view, "delete", %{"id" => theirs.id}))
      end)

      assert File.exists?(Uploads.path(theirs.path))
    end

    test "a signature saved elsewhere (a bill's page, another tab) shows up", %{
      conn: conn,
      scope: scope
    } do
      {:ok, view, _html} = live(conn, ~p"/signatures")
      refute has_element?(view, "#signatures tr")

      signature = signature_fixture(scope, %{name: "From a bill"})

      assert has_element?(view, "#signatures-#{signature.id}", "From a bill")
    end

    test "at the limit the form gives way to a note", %{conn: conn, scope: scope} do
      for n <- 1..Signatures.max_per_user(), do: signature_fixture(scope, %{name: "Sig #{n}"})

      {:ok, view, _html} = live(conn, ~p"/signatures")

      refute has_element?(view, "#signature-form")
      assert has_element?(view, "#signature-limit")
    end
  end
end
