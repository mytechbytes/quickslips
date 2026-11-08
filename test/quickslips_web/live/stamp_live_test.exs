defmodule QuickSlipsWeb.StampLiveTest do
  use QuickSlipsWeb.ConnCase

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import QuickSlips.StampsFixtures
  import QuickSlips.UploadsFixtures

  alias QuickSlips.Stamps
  alias QuickSlips.Uploads

  test "visitors are sent to the log-in page", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/users/log-in"}}} = live(conn, ~p"/stamps")
  end

  describe "when logged in" do
    setup :register_and_log_in_user

    setup %{user: user} do
      on_exit(fn -> File.rm_rf(Path.join(Uploads.root(), Integer.to_string(user.id))) end)
    end

    defp choose(live, name, content, type \\ "image/png") do
      live
      |> file_input("#stamp-form", :stamp, [%{name: name, content: content, type: type}])
      |> render_upload(name)
    end

    defp stored_files(user),
      do: Path.wildcard(Path.join([Uploads.root(), Integer.to_string(user.id), "*"]))

    test "lists the user's stamps with their pictures, and nobody else's", %{
      conn: conn,
      scope: scope
    } do
      mine = stamp_fixture(scope, %{name: "Owner"})

      theirs =
        stamp_fixture(QuickSlips.AccountsFixtures.user_scope_fixture(), %{name: "Not mine"})

      {:ok, view, html} = live(conn, ~p"/stamps")

      assert has_element?(view, "#stamps-#{mine.id}", "Owner")
      assert html =~ ~s(src="/uploads/#{mine.path}")
      refute has_element?(view, "#stamps-#{theirs.id}")
      refute has_element?(view, "#no-stamps")
    end

    test "says so when there are none yet", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/stamps")

      assert has_element?(view, "#no-stamps")
      assert has_element?(view, "#stamp-form")
    end

    test "is in the menu", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/stamps")

      assert has_element?(view, ~s(#nav-stamps[href="/stamps"]), "Stamps")
    end

    test "saves a stamp: the name and the picture", %{conn: conn, user: user, scope: scope} do
      {:ok, view, _html} = live(conn, ~p"/stamps")
      choose(view, "sign.png", png_bytes())

      html = view |> form("#stamp-form", stamp: %{name: "Owner"}) |> render_submit()

      assert html =~ "Stamp saved."
      assert [%{name: "Owner", path: path}] = Stamps.list_stamps(scope)
      assert path =~ ~r/^#{user.id}\/[a-f0-9]{16}\.png$/
      assert File.read!(Uploads.path(path)) == png_bytes()
      assert has_element?(view, "#stamps", "Owner")
      refute has_element?(view, "#no-stamps")
      # The form is empty again, ready for the next one.
      refute render(view) =~ "sign.png"
    end

    test "a name is needed, and the chosen file waits", %{conn: conn, user: user, scope: scope} do
      {:ok, view, _html} = live(conn, ~p"/stamps")
      choose(view, "sign.png", png_bytes())

      html = view |> form("#stamp-form", stamp: %{name: "  "}) |> render_submit()

      assert html =~ "can&#39;t be blank"
      assert html =~ "sign.png"
      assert Stamps.list_stamps(scope) == []
      assert stored_files(user) == []
    end

    test "a name that is taken is told, and the chosen file waits", %{
      conn: conn,
      user: user,
      scope: scope
    } do
      stamp_fixture(scope, %{name: "Owner"})
      {:ok, view, _html} = live(conn, ~p"/stamps")
      choose(view, "second.png", png_bytes())

      html = view |> form("#stamp-form", stamp: %{name: "owner"}) |> render_submit()

      assert html =~ "is already used by another of your stamps"
      assert html =~ "second.png"
      assert Stamps.count_stamps(scope) == 1
      assert length(stored_files(user)) == 1

      # With another name, the same file goes through.
      html = view |> form("#stamp-form", stamp: %{name: "Manager"}) |> render_submit()

      assert html =~ "Stamp saved."
      assert Stamps.count_stamps(scope) == 2
    end

    test "a picture is needed", %{conn: conn, scope: scope} do
      {:ok, view, _html} = live(conn, ~p"/stamps")

      html = view |> form("#stamp-form", stamp: %{name: "Owner"}) |> render_submit()

      assert html =~ "Choose a picture of the stamp first."
      assert Stamps.list_stamps(scope) == []
    end

    test "a file that is not really a picture is turned down", %{
      conn: conn,
      user: user,
      scope: scope
    } do
      {:ok, view, _html} = live(conn, ~p"/stamps")
      choose(view, "sign.png", "this is only text")

      html = view |> form("#stamp-form", stamp: %{name: "Owner"}) |> render_submit()

      assert html =~ "The stamp is not a real PNG or JPG picture."
      assert Stamps.list_stamps(scope) == []
      assert stored_files(user) == []
    end

    test "a wrong type and a file over 1 MB are refused at once", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/stamps")

      svg =
        file_input(view, "#stamp-form", :stamp, [
          %{name: "sign.svg", content: "<svg></svg>", type: "image/svg+xml"}
        ])

      assert {:error, [[_ref, :not_accepted]]} = render_upload(svg, "sign.svg")
      assert render(view) =~ "Only PNG and JPG files can be used."

      {:ok, view, _html} = live(conn, ~p"/stamps")

      big =
        file_input(view, "#stamp-form", :stamp, [
          %{name: "big.png", content: :binary.copy("a", 1_000_001), type: "image/png"}
        ])

      assert {:error, [[_ref, :too_large]]} = render_upload(big, "big.png")
      assert render(view) =~ "This file is too big. The limit is 1 MB."
    end

    test "a chosen file can be taken back", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/stamps")
      choose(view, "sign.png", png_bytes())
      assert render(view) =~ "sign.png"

      view |> element("#stamp-field button", "Remove") |> render_click()

      refute render(view) =~ "sign.png"
    end

    test "deletes a stamp and its file", %{conn: conn, scope: scope} do
      stamp = stamp_fixture(scope, %{name: "Owner"})
      {:ok, view, _html} = live(conn, ~p"/stamps")

      view |> element("#delete-stamps-#{stamp.id}") |> render_click()

      refute has_element?(view, "#stamps-#{stamp.id}")
      assert Stamps.list_stamps(scope) == []
      refute File.exists?(Uploads.path(stamp.path))
      assert has_element?(view, "#no-stamps")
    end

    test "can't delete somebody else's stamp", %{conn: conn} do
      theirs = stamp_fixture(QuickSlips.AccountsFixtures.user_scope_fixture())
      {:ok, view, _html} = live(conn, ~p"/stamps")
      # The page crashes (a 404 for the request), and the test must outlive it.
      Process.flag(:trap_exit, true)

      capture_log(fn ->
        assert catch_exit(render_click(view, "delete", %{"id" => theirs.id}))
      end)

      assert File.exists?(Uploads.path(theirs.path))
    end

    test "a stamp saved elsewhere (a bill's page, another tab) shows up", %{
      conn: conn,
      scope: scope
    } do
      {:ok, view, _html} = live(conn, ~p"/stamps")
      refute has_element?(view, "#stamps tr")

      stamp = stamp_fixture(scope, %{name: "From a bill"})

      assert has_element?(view, "#stamps-#{stamp.id}", "From a bill")
    end

    test "at the limit the form gives way to a note", %{conn: conn, scope: scope} do
      for n <- 1..Stamps.max_per_user(), do: stamp_fixture(scope, %{name: "Sig #{n}"})

      {:ok, view, _html} = live(conn, ~p"/stamps")

      refute has_element?(view, "#stamp-form")
      assert has_element?(view, "#stamp-limit")
    end
  end
end
