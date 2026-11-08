defmodule QuickSlipsWeb.LegalLiveTest do
  # The contact address is a setting of the whole application, so these tests run one at a time.
  use QuickSlipsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import QuickSlips.AccountsFixtures
  import QuickSlips.SiteHelpers

  # The terms of use, the privacy policy and the disclaimer. The tests look at what the pages promise to say (that
  # they are there, that they agree with each other and with what the app does), not at the wording, which is a
  # legal matter.

  @pages [
    {"/terms", "legal-terms", "Terms of use"},
    {"/privacy", "legal-privacy", "Privacy policy"},
    {"/disclaimer", "legal-disclaimer", "Disclaimer"}
  ]

  defp document(html), do: LazyHTML.from_document(html)
  defp page(conn, path), do: conn |> get(path) |> html_response(200) |> document()

  defp texts(doc, selector),
    do: doc |> LazyHTML.query(selector) |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))

  # The words of one page, as one line: where the source breaks a line is not part of what it says.
  defp words(conn, path, id) do
    conn
    |> page(path)
    |> LazyHTML.query("##{id}")
    |> LazyHTML.text()
    |> String.split()
    |> Enum.join(" ")
  end

  describe "each page" do
    test "is there for everybody, with its title and the date of its text", %{conn: conn} do
      for {path, id, title} <- @pages do
        doc = page(conn, path)

        assert texts(doc, "##{id} h1") == [title], path
        assert [updated] = texts(doc, "##{id}-updated")
        assert updated =~ ~r/^Last updated: \d{1,2} [A-Z][a-z]+ \d{4}$/, path
        assert [page_title] = texts(doc, "title")
        assert page_title == "#{title} · QuickSlips"
      end
    end

    test "has its text in sections", %{conn: conn} do
      for {path, id, _title} <- @pages do
        sections = conn |> page(path) |> texts("##{id} h2")

        assert length(sections) >= 5, path
        assert sections == Enum.uniq(sections), path
      end
    end

    test "is a page of the site: the footer is there and a click on it is a live navigation", %{
      conn: conn
    } do
      for {path, _id, _title} <- @pages do
        {:ok, view, _html} = live(conn, path)
        assert has_element?(view, "#site-footer"), path
      end

      {:ok, view, _html} = live(conn, ~p"/en-in")

      assert {:error, {:live_redirect, %{to: "/terms"}}} =
               view |> element("#footer-site a", "Terms") |> render_click()
    end

    test "is the same for a logged-in user, in the app's shell", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      for {path, id, title} <- @pages do
        {:ok, view, _html} = live(conn, path)
        assert has_element?(view, "##{id} h1", title)
        refute has_element?(view, "#site-footer")
      end
    end
  end

  describe "the three pages together" do
    test "point to each other", %{conn: conn} do
      links = fn path, id ->
        conn
        |> page(path)
        |> LazyHTML.query("##{id} a[href^='/']")
        |> Enum.flat_map(&LazyHTML.attribute(&1, "href"))
      end

      assert "/disclaimer" in links.("/terms", "legal-terms")
      assert "/privacy" in links.("/terms", "legal-terms")
      assert "/terms" in links.("/privacy", "legal-privacy")
      assert "/terms" in links.("/disclaimer", "legal-disclaimer")
      assert "/privacy" in links.("/disclaimer", "legal-disclaimer")
    end

    test "both say that a document is for real transactions only, and is not official", %{
      conn: conn
    } do
      terms = words(conn, "/terms", "legal-terms")
      disclaimer = words(conn, "/disclaimer", "legal-disclaimer")

      assert terms =~ "really happened"
      assert terms =~ "not official invoices"
      assert disclaimer =~ "really happened"
      assert disclaimer =~ "Not an official document"
    end
  end

  describe "the privacy policy" do
    test "names the cookies that the app really sets", %{conn: conn} do
      listed = conn |> page("/privacy") |> texts("#legal-cookies code")

      # A visitor's first page: the identifier for the daily limit, and the session.
      visit = get(conn, ~p"/en-in")
      assert visit.resp_cookies["vid"]
      assert visit.resp_cookies["_quickslips_key"]

      # The choice of a language is the only thing that sets the locale cookie.
      chosen = post(build_conn(), ~p"/locale", %{"locale" => "hi-in", "from" => "/en-in"})
      assert chosen.resp_cookies[QuickSlipsWeb.Plugs.Locale.cookie_name()]

      # And "keep me logged in" sets the other.
      user = set_password(user_fixture())

      remembered =
        post(build_conn(), ~p"/users/log-in", %{
          "user" => %{
            "email" => user.email,
            "password" => valid_user_password(),
            "remember_me" => "true"
          }
        })

      assert remembered.resp_cookies["_quick_slips_web_user_remember_me"]

      assert Enum.sort(listed) ==
               Enum.sort([
                 "_quickslips_key",
                 "_quick_slips_web_user_remember_me",
                 "vid",
                 QuickSlipsWeb.Plugs.Locale.cookie_name()
               ])
    end

    test "says what is kept for an account, and for a visitor who has none", %{conn: conn} do
      text = words(conn, "/privacy", "legal-privacy")

      assert text =~ "latest 200 documents"
      assert text =~ "we do not keep those details or the PDF"
      assert text =~ "Cloudflare"
      assert text =~ "Google"
    end
  end

  describe "the contact address" do
    test "is not on any page while none is set: nobody is invited to write to an address that does not exist",
         %{
           conn: conn
         } do
      put_contact_email(nil)

      for {path, id, _title} <- @pages do
        doc = page(conn, path)

        refute LazyHTML.query(doc, "##{id} a[href^='mailto:']") |> Enum.any?(), path
        refute "Contact" in texts(doc, "##{id} h2"), path
      end
    end

    test "is on every page, as a link, once it is set", %{conn: conn} do
      put_contact_email("hello@example.org")

      for {path, id, _title} <- @pages do
        doc = page(conn, path)

        assert doc |> LazyHTML.query("##{id} a[href='mailto:hello@example.org']") |> Enum.count() >=
                 1,
               path

        assert "Contact" in texts(doc, "##{id} h2"), path
      end
    end

    test "leads to the contact form from every page once it is set, and from none before", %{
      conn: conn
    } do
      put_contact_email(nil)

      for {path, id, _title} <- @pages do
        refute conn |> page(path) |> LazyHTML.query("##{id} a[href='/contact']") |> Enum.any?(),
               path
      end

      put_contact_email("hello@example.org")

      for {path, id, _title} <- @pages do
        assert conn |> page(path) |> LazyHTML.query("##{id} a[href='/contact']") |> Enum.any?(),
               path
      end
    end

    test "is what the account of the contact form in the privacy policy refers to", %{conn: conn} do
      put_contact_email(nil)
      refute conn |> page("/privacy") |> LazyHTML.query("#legal-contact-messages") |> Enum.any?()
      refute words(conn, "/privacy", "legal-privacy") =~ "contact form"

      put_contact_email("hello@example.org")
      text = words(conn, "/privacy", "legal-contact-messages")

      assert text =~ "Messages you send us."
      assert text =~ "We keep the message in our database, under a reference that we give you"
      assert text =~ "we send a confirmation to the address you gave"
      assert text =~ "your name and your words"
      assert text =~ "Everybody who uses the form passes the Turnstile check"
      assert text =~ "scrambled form of it, not under the address itself"

      privacy = words(conn, "/privacy", "legal-privacy")

      assert privacy =~
               "Messages from the contact form, in our database and in our mailbox: for as long as we need them"

      assert privacy =~ "their confirmations to the people who wrote them"
    end

    test "is what the promises of deleting an account refer to", %{conn: conn} do
      put_contact_email(nil)
      refute words(conn, "/privacy", "legal-privacy") =~ "close your account"

      put_contact_email("hello@example.org")
      assert words(conn, "/privacy", "legal-privacy") =~ "close your account"
    end
  end

  describe "for a visitor whose language is not English" do
    test "tells them, in their language, that the page is in English", %{conn: conn} do
      for {locale, notice} <- [
            {"es-es", "Esta página solo está disponible en inglés."},
            {"hi-in", "यह पेज केवल अंग्रेज़ी में उपलब्ध है।"},
            {"ja-jp", "このページは英語のみで提供しています。"}
          ] do
        html =
          conn
          |> get("/#{locale}")
          |> recycle()
          |> get(~p"/terms")
          |> html_response(200)
          |> document()

        assert texts(html, "#legal-english-only") == [notice], locale
      end
    end

    test "says nothing to a visitor who reads English", %{conn: conn} do
      doc =
        conn
        |> get(~p"/en-in")
        |> recycle()
        |> get(~p"/terms")
        |> html_response(200)
        |> document()

      assert texts(doc, "#legal-english-only") == []
    end
  end
end
