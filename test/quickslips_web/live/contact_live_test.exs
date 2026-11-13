defmodule QuickSlipsWeb.ContactLiveTest do
  # The contact address and the ceilings are settings of the whole application, so these tests run one at a time.
  use QuickSlipsWeb.ConnCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest
  import QuickSlips.SiteHelpers
  import QuickSlips.TaskHelpers

  alias QuickSlips.Contact.Message
  alias QuickSlips.Repo
  alias QuickSlipsWeb.Endpoint

  # The page where a visitor writes to the owner. The words are not tested but what the page does: which parts it
  # has, what it asks of a visitor and of a user, what it does with the answer of the checks, and what follows a
  # message (it is kept, and two e-mails go out).

  setup do
    put_contact_email("owner@example.org")

    # the e-mails go out in a task: one still running when a test ends would find its database connection gone
    on_exit(&wait_for_tasks/0)
    :ok
  end

  @message %{
    "topic" => "problem",
    "name" => "Asha Rao",
    "email" => "asha@example.com",
    "message" => "The fuel bill has no line for GST."
  }

  defp document(html), do: LazyHTML.from_document(html)

  defp fill(view, extra \\ %{}) do
    form(view, "#contact-form", contact: Map.merge(@message, extra))
  end

  # What Cloudflare answers to the check, for the LiveView of `view`.
  defp turnstile_says(view, success?) do
    Req.Test.stub(QuickSlips.Turnstile, fn conn ->
      Req.Test.json(conn, %{"success" => success?})
    end)

    Req.Test.allow(QuickSlips.Turnstile, self(), view.pid)
  end

  # What the widget does in the browser: it gives the page a token.
  defp token(view, token \\ "a-good-token"),
    do: render_hook(view, "turnstile", %{"token" => token})

  # A page that has passed the check, ready to be filled in.
  defp checked(conn, path \\ ~p"/contact") do
    {:ok, view, _html} = live(conn, path)
    turnstile_says(view, true)
    token(view)
    view
  end

  # Every e-mail that was sent since the last call, oldest first, once the tasks that send them are done.
  defp emails(found \\ []) do
    wait_for_tasks()

    receive do
      {:email, email} -> emails([email | found])
    after
      0 -> Enum.reverse(found)
    end
  end

  defp to_owner(emails), do: Enum.find(emails, &(&1.to == [{"", "owner@example.org"}]))
  defp to_sender(emails), do: Enum.find(emails, &(&1.to != [{"", "owner@example.org"}]))

  defp kept, do: Repo.all(Message)

  describe "the page" do
    test "is there for everybody, with the kinds of message and the fields", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      assert has_element?(view, "h1#contact-title")
      assert has_element?(view, "#contact-lead")
      assert has_element?(view, "form#contact-form")

      for topic <- ~w(change feedback problem complaint other) do
        assert has_element?(view, ~s(#contact-topic-#{topic} input[type=radio][value=#{topic}]))
      end

      assert has_element?(view, "#contact_name")
      assert has_element?(view, "#contact_email[type=email][required]")
      assert has_element?(view, "#contact_message[required]")
      assert has_element?(view, "#contact-send")
    end

    test "offers the owner's address for those who prefer e-mail", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      assert has_element?(
               view,
               ~s(#contact-email-fallback a[href="mailto:owner@example.org"]),
               "owner@example.org"
             )
    end

    test "starts with feedback chosen, or with the kind that the link asks for", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")
      assert has_element?(view, "#contact-topic-feedback input[checked]")
      refute has_element?(view, "#contact-topic-change input[checked]")

      {:ok, view, _html} = live(conn, ~p"/contact?topic=change")
      assert has_element?(view, "#contact-topic-change input[checked]")
      refute has_element?(view, "#contact-topic-feedback input[checked]")

      {:ok, view, _html} = live(conn, ~p"/contact?topic=refund")
      assert has_element?(view, "#contact-topic-feedback input[checked]")
    end

    test "says which page the visitor comes from, when it is a page of this site", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact?about=/en-in/fuel-bill-generator")
      assert has_element?(view, "#contact-about", "/en-in/fuel-bill-generator")

      for other <- [
            "https://evil.example/phish",
            "//evil.example/phish",
            "/../etc/passwd",
            "/with space",
            "/" <> String.duplicate("a", 200),
            "javascript:alert(1)"
          ] do
        {:ok, view, _html} = live(conn, ~p"/contact?#{[about: other]}")
        refute has_element?(view, "#contact-about"), other
      end
    end

    test "asks for the Turnstile check", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      assert has_element?(
               view,
               ~s(#contact-turnstile[phx-hook=ContactTurnstile][phx-update=ignore][data-site-key=test])
             )
    end

    test "keeps the trap for robots out of sight and out of reach", %{conn: conn} do
      html = conn |> get(~p"/contact") |> html_response(200) |> document()

      assert [trap] = html |> LazyHTML.query("input[name='contact[website]']") |> Enum.to_list()
      assert LazyHTML.attribute(trap, "tabindex") == ["-1"]
      assert LazyHTML.attribute(trap, "autocomplete") == ["off"]

      assert html
             |> LazyHTML.query("[aria-hidden=true] input[name='contact[website]']")
             |> Enum.count() == 1
    end

    test "has the footer of the public pages", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")
      assert has_element?(view, "#site-footer")
    end

    test "has no form when there is no address to tell: it says so", %{conn: conn} do
      put_contact_email(nil)
      {:ok, view, _html} = live(conn, ~p"/contact")

      assert has_element?(view, "#contact-unavailable")
      refute has_element?(view, "#contact-form")
      refute has_element?(view, "#contact-send")
    end
  end

  describe "in the language of the visitor" do
    test "speaks it, down to the answers of the form", %{conn: conn} do
      for {locale, language, title, topic, button} <- [
            {"es-es", "es", "¿En qué podemos ayudarte?", "Pedir un cambio", "Enviar mensaje"},
            {"hi-in", "hi", "हम कैसे मदद कर सकते हैं?", "बदलाव माँगें", "संदेश भेजें"},
            {"ja-jp", "ja", "どのようなご用件ですか？", "変更を依頼する", "メッセージを送信"},
            {"fr-fr", "fr", "Comment pouvons-nous vous aider ?", "Demander une modification",
             "Envoyer le message"}
          ] do
        conn = conn |> get("/#{locale}") |> recycle()
        {:ok, view, _html} = live(conn, ~p"/contact")

        assert has_element?(view, "#contact-title", title), locale
        assert has_element?(view, "#contact-topic-change", topic), locale
        assert has_element?(view, "#contact-send", button), locale

        # what the form says is wrong is in the language too, not only what the page says
        view |> fill(%{"message" => ""}) |> render_submit()

        blank =
          Gettext.with_locale(QuickSlipsWeb.Gettext, language, fn ->
            Gettext.dgettext(QuickSlipsWeb.Gettext, "errors", "can't be blank")
          end)

        assert has_element?(view, "#contact_message-error", blank), locale
        refute blank == "can't be blank"
      end
    end

    test "has the title of the page in the language too", %{conn: conn} do
      html = conn |> get("/es-es") |> recycle() |> get(~p"/contact") |> html_response(200)

      assert html |> document() |> LazyHTML.query("title") |> LazyHTML.text() =~ "Contacto"
    end

    test "sends the confirmation in the language of the page, and says so on the page", %{
      conn: conn
    } do
      conn = conn |> get("/hi-in") |> recycle()
      view = checked(conn)

      view |> fill() |> render_submit()

      [message] = kept()
      assert has_element?(view, "#contact-sent-reference", message.reference)
      assert has_element?(view, "#contact-sent-confirmation", "asha@example.com")

      email = emails() |> to_sender()
      assert email.subject == "QuickSlips को आपका संदेश (#{message.reference})"
      assert email.text_body =~ "संदर्भ: #{message.reference}"
    end
  end

  describe "sending" do
    test "keeps the message, tells the owner and the sender, and says thank you with the reference",
         %{
           conn: conn
         } do
      view = checked(conn)

      view |> fill() |> render_submit()

      assert has_element?(view, "#contact-sent")
      refute has_element?(view, "#contact-form")

      # the panel takes the focus, so that a keyboard or a screen reader is not left on a button that is gone
      assert has_element?(view, "#contact-sent[tabindex='-1'][phx-mounted]")

      assert [message] = kept()

      assert %{topic: :problem, name: "Asha Rao", email: "asha@example.com", status: :new} =
               message

      assert message.reference =~ ~r/\A[A-Z2-7]{4}-[A-Z2-7]{4}\z/
      assert has_element?(view, "#contact-sent-reference", message.reference)
      assert has_element?(view, "#contact-sent-confirmation", "asha@example.com")

      emails = emails()
      assert length(emails) == 2

      owner = to_owner(emails)
      assert owner.reply_to == {"Asha Rao", "asha@example.com"}
      assert owner.subject == "[QuickSlips] Problem report: The fuel bill has no line for GST."
      assert owner.text_body =~ "en-IN"
      assert owner.text_body =~ "#{Endpoint.url()}/admin/messages/#{message.id}"
      refute owner.text_body =~ "Account:"

      sender = to_sender(emails)
      assert sender.to == [{"", "asha@example.com"}]
      assert sender.subject == "Your message to QuickSlips (#{message.reference})"
    end

    test "asks Cloudflare about the token it was given, and about nothing else", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")
      test_pid = self()

      Req.Test.stub(QuickSlips.Turnstile, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        send(test_pid, {:asked, URI.decode_query(body)})
        Req.Test.json(conn, %{"success" => true})
      end)

      Req.Test.allow(QuickSlips.Turnstile, self(), view.pid)
      token(view, "the-token")
      view |> fill() |> render_submit()

      assert_received {:asked, %{"response" => "the-token", "secret" => "test"} = asked}
      # the address of the visitor is not known to a LiveView, and Cloudflare does not need it
      refute Map.has_key?(asked, "remoteip")
    end

    test "does not send without a token, says why, and keeps what was written", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      view |> fill() |> render_submit()

      assert has_element?(view, "#contact-error")
      refute has_element?(view, "#contact-sent")
      assert kept() == []
      assert emails() == []

      assert has_element?(view, ~s(#contact_email[value="asha@example.com"]))
      assert has_element?(view, "#contact_message", "The fuel bill has no line for GST.")
    end

    test "does not send when Cloudflare does not accept the token", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")
      turnstile_says(view, false)
      token(view, "a-bad-token")

      view |> fill() |> render_submit()

      assert has_element?(view, "#contact-error")
      assert kept() == []
      assert emails() == []
    end

    test "asks the widget for a new token after every check: one is good for one", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")
      turnstile_says(view, false)
      token(view)

      view |> fill() |> render_submit()
      assert_push_event(view, "turnstile:reset", %{})

      # and the token that was spent is not used again
      view |> fill() |> render_submit()
      assert has_element?(view, "#contact-error")
      assert kept() == []
    end

    test "a token that has run out is no token", %{conn: conn} do
      view = checked(conn)
      token(view, nil)

      view |> fill() |> render_submit()

      assert has_element?(view, "#contact-error")
      assert kept() == []
    end

    test "does not ask Cloudflare when the message is not fine: it shows what is wrong", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/contact")

      view |> fill(%{"email" => "not-an-address", "message" => ""}) |> render_submit()

      assert has_element?(view, "#contact_email-error")
      assert has_element?(view, "#contact_message-error")
      refute has_element?(view, "#contact-error")
      assert kept() == []
    end

    test "thanks a robot as well, keeps nothing and tells nobody", %{conn: conn} do
      view = checked(conn)

      view |> fill(%{"website" => "https://cheap-pills.example"}) |> render_submit()

      assert has_element?(view, "#contact-sent")
      assert has_element?(view, "#contact-sent-reference")
      assert kept() == []
      assert emails() == []
    end

    test "keeps which language and country the page was in, and which page it is about", %{
      conn: conn
    } do
      conn = conn |> get(~p"/hi-in") |> recycle()
      view = checked(conn, ~p"/contact?topic=change&about=/hi-in/fuel-bill-generator")

      view |> fill(%{"topic" => "change"}) |> render_submit()

      assert [%{topic: :change, locale: "hi-IN", page: "/hi-in/fuel-bill-generator"}] = kept()

      body = emails() |> to_owner() |> Map.fetch!(:text_body)
      assert body =~ "Change request"
      assert body =~ "hi-IN"
      assert body =~ "#{Endpoint.url()}/hi-in/fuel-bill-generator"
    end

    test "thanks the visitor all the same when the e-mails cannot be sent: the message is kept",
         %{
           conn: conn
         } do
      previous = Application.fetch_env!(:quickslips, QuickSlips.Mailer)
      on_exit(fn -> Application.put_env(:quickslips, QuickSlips.Mailer, previous) end)
      Application.put_env(:quickslips, QuickSlips.Mailer, adapter: QuickSlips.FailingMailAdapter)

      view = checked(conn)

      capture_log(fn ->
        view |> fill() |> render_submit()
        wait_for_tasks()
      end)

      assert has_element?(view, "#contact-sent")

      assert [%{owner_notified_at: nil, confirmation_sent_at: nil, email: "asha@example.com"}] =
               kept()
    end
  end

  describe "the form" do
    test "shows what is wrong while it is being filled in, and stops when it is right", %{
      conn: conn
    } do
      {:ok, view, _html} = live(conn, ~p"/contact")

      view |> form("#contact-form", contact: %{"email" => "asha@"}) |> render_change()
      assert has_element?(view, "#contact_email-error")

      view |> form("#contact-form", contact: %{"email" => "asha@example.com"}) |> render_change()
      refute has_element?(view, "#contact_email-error")
    end

    test "does not complain of what has not been touched yet", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      # what the browser sends when someone types in the name: all the fields, and which ones are still unused
      render_change(view, "validate", %{
        "contact" => %{
          "name" => "Asha",
          "email" => "",
          "message" => "",
          "_unused_email" => "",
          "_unused_message" => ""
        }
      })

      refute has_element?(view, "#contact_email-error")
      refute has_element?(view, "#contact_message-error")
    end

    test "takes the kind of message that is chosen", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      view |> form("#contact-form", contact: %{"topic" => "complaint"}) |> render_change()

      assert has_element?(view, "#contact-topic-complaint input[checked]")
      refute has_element?(view, "#contact-topic-feedback input[checked]")
    end

    test "gives a clean form for another message", %{conn: conn} do
      view = checked(conn)
      view |> fill() |> render_submit()

      view |> element("#contact-again") |> render_click()

      assert has_element?(view, "#contact-form")
      refute has_element?(view, "#contact-sent")
      refute has_element?(view, ~s(#contact_email[value="asha@example.com"]))
    end

    test "a second send of the same message, while the first is answered, is ignored", %{
      conn: conn
    } do
      view = checked(conn)
      view |> fill() |> render_submit()
      assert length(kept()) == 1

      render_hook(view, "send", %{"contact" => @message})

      assert length(kept()) == 1
      assert has_element?(view, "#contact-sent")
    end
  end

  describe "when the day's ceiling is reached" do
    test "says so, and keeps the form", %{conn: conn} do
      put_contact_limits(user: 1, all: 1, to: 5)
      view = checked(conn)

      view |> fill() |> render_submit()
      assert has_element?(view, "#contact-sent")

      view |> element("#contact-again") |> render_click()
      token(view)
      view |> fill() |> render_submit()

      assert has_element?(view, "#contact-error")
      assert has_element?(view, "#contact-form")
      assert has_element?(view, "#contact_message", "The fuel bill has no line for GST.")
      assert length(kept()) == 1
    end
  end

  describe "for a logged-in user" do
    setup :register_and_log_in_user

    test "has the form filled in with the account's address", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      assert has_element?(view, ~s(#contact_email[value="#{user.email}"]))
    end

    test "passes the Turnstile check too: the confirmation goes to the address that is typed, and an account " <>
           "does not make it theirs",
         %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")
      assert has_element?(view, "#contact-turnstile[data-site-key=test]")

      view |> fill() |> render_submit()

      assert has_element?(view, "#contact-error")
      assert kept() == []
      assert emails() == []
    end

    test "is inside the app, which has its own shell and the footer", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/contact")

      assert has_element?(view, "#contact-form")
      assert has_element?(view, "#site-footer")
      assert has_element?(view, "#nav-contact[aria-current=page]")
    end

    test "can send once the check is passed, and the owner is told whose message it is", %{
      conn: conn,
      user: user
    } do
      view = checked(conn)

      view |> fill() |> render_submit()

      assert has_element?(view, "#contact-sent")
      assert [%{user_id: user_id}] = kept()
      assert user_id == user.id

      assert emails() |> to_owner() |> Map.fetch!(:text_body) =~
               "#{user.email} (user #{user.id})"
    end

    test "has a ceiling of its own", %{conn: conn} do
      put_contact_limits(user: 1, all: 50, to: 5)
      view = checked(conn)

      view |> fill() |> render_submit()
      view |> element("#contact-again") |> render_click()
      token(view)
      view |> fill() |> render_submit()

      assert has_element?(view, "#contact-error")
      assert length(kept()) == 1
    end

    test "starts a new message with the account's address again", %{conn: conn, user: user} do
      view = checked(conn)
      view |> fill(%{"email" => "other@example.com"}) |> render_submit()

      view |> element("#contact-again") |> render_click()

      assert has_element?(view, ~s(#contact_email[value="#{user.email}"]))
    end
  end
end
