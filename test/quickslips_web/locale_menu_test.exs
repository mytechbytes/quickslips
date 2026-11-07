defmodule QuickSlipsWeb.LocaleMenuTest do
  use QuickSlipsWeb.ConnCase

  import Phoenix.LiveViewTest

  # The language and country switch is in the header and in the footer of every public page.

  describe "in the header and the footer of a public page" do
    test "has a button for each live locale, and none for the others", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/en-in")

      assert has_element?(view, "#locale-menu-trigger")

      for code <-
            ~w(en-in hi-in es-es en-us zh-cn de-de ja-jp en-gb fr-fr it-it pt-br en-ca fr-ca) do
        assert has_element?(
                 view,
                 ~s(#locale-menu-#{code}[type=submit][form=locale-menu-form][name=locale][value=#{code}])
               )

        assert has_element?(
                 view,
                 ~s(#footer-locale-#{code}[type=submit][form=footer-locale-form][name=locale][value=#{code}])
               )
      end

      for code <- ["es-mx", "xx-yy"] do
        refute has_element?(view, "#locale-menu-#{code}")
        refute has_element?(view, "#footer-locale-#{code}")
      end
    end

    test "the buttons belong to a form that posts to /locale with a token and the address", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/en-in")

      for form <- ["locale-menu-form", "footer-locale-form"] do
        assert has_element?(
                 view,
                 ~s(form##{form}[action="/locale"][method=post][data-locale-form])
               )

        assert has_element?(view, ~s(form##{form} input[type=hidden][name=_csrf_token]))
        assert has_element?(view, ~s(form##{form} input[type=hidden][name=from]))
      end
    end

    test "marks the locale of the page", %{conn: conn} do
      for {path, current} <- [{"/en-in", "en-in"}, {"/hi-in", "hi-in"}, {"/es-es", "es-es"}] do
        {:ok, view, _html} = live(conn, path)

        for prefix <- ["locale-menu", "footer-locale"], code <- ["en-in", "hi-in", "es-es"] do
          assert has_element?(view, "##{prefix}-#{code}[aria-current=true]") == (code == current)
        end
      end
    end

    test "says what is chosen, in the language of the page", %{conn: conn} do
      for {path, text} <- [
            {"/en-in", "English · India · INR"},
            {"/hi-in", "हिन्दी · भारत · INR"},
            {"/es-es", "Español · España · EUR"}
          ] do
        {:ok, view, _html} = live(conn, path)

        assert view
               |> element("#locale-menu-trigger")
               |> render()
               |> LazyHTML.from_fragment()
               |> LazyHTML.text()
               |> String.replace(~r/\s+/, " ") =~
                 text
      end
    end

    test "groups the languages by country, and names the countries in the language of the page",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/hi-in")

      assert has_element?(
               view,
               ~s(#locale-menu [role=group][aria-label="भारत"] #locale-menu-en-in)
             )

      assert has_element?(
               view,
               ~s(#locale-menu [role=group][aria-label="भारत"] #locale-menu-hi-in)
             )

      assert has_element?(view, ~s(#locale-menu [role=group][aria-label="स्पेन"] #locale-menu-es-es))

      {:ok, view, _html} = live(conn, ~p"/es-es")

      assert has_element?(
               view,
               ~s(#footer-locale [role=group][aria-label="India"] #footer-locale-hi-in)
             )

      assert has_element?(
               view,
               ~s(#footer-locale [role=group][aria-label="España"] #footer-locale-es-es)
             )
    end

    test "names each language in its own language, so a visitor can find theirs", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/en-in")

      assert has_element?(view, ~s(#locale-menu-hi-in[lang=hi]), "हिन्दी")
      assert has_element?(view, ~s(#locale-menu-es-es[lang=es]), "Español")
      assert has_element?(view, ~s(#locale-menu-en-in[lang=en]), "English")
    end
  end

  describe "on every kind of page" do
    test "on a bill, which is not a LiveView", %{conn: conn} do
      html =
        conn
        |> get(~p"/hi-in/fuel-bill-generator")
        |> html_response(200)
        |> LazyHTML.from_document()

      assert html |> LazyHTML.query("#locale-menu-es-es[form=locale-menu-form]") |> Enum.count() ==
               1

      assert html |> LazyHTML.query("#footer-locale-hi-in[aria-current=true]") |> Enum.count() ==
               1

      assert html |> LazyHTML.query("form#locale-menu-form") |> Enum.count() == 1
    end

    test "on the log-in page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/users/log-in")

      assert has_element?(view, "#locale-menu-trigger")
      assert has_element?(view, "#footer-locale-es-es")
    end

    test "in the header of the app a logged-in user sees, on a laptop and on a phone", %{
      conn: conn
    } do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      {:ok, view, _html} = live(conn, ~p"/en-in")

      assert has_element?(view, "#locale-menu-trigger")
      assert has_element?(view, "#locale-menu-hi-in")
      assert has_element?(view, "#m-locale-menu-trigger")
      assert has_element?(view, "#m-locale-menu-es-es[form=m-locale-menu-form]")
    end
  end
end
