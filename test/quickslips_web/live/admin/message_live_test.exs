defmodule QuickSlipsWeb.Admin.MessageLiveTest do
  # The admins are a setting of the whole application, so these tests run one at a time.
  use QuickSlipsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import QuickSlips.AccountsFixtures
  import QuickSlips.ContactFixtures
  import QuickSlips.SiteHelpers
  import QuickSlips.TaskHelpers

  alias QuickSlips.Accounts.Scope
  alias QuickSlips.Contact
  alias QuickSlips.Contact.Message
  alias QuickSlips.Repo

  # The pages where the owner reads what visitors wrote: who may open them, what they show, and what the owner can do
  # with a message. The words are not tested but what the pages do.

  setup do
    on_exit(&wait_for_tasks/0)
    :ok
  end

  defp stored(message), do: Repo.get!(Message, message.id)

  # The ids of the rows of the list, top to bottom.
  defp row_ids(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#messages > li")
    |> Enum.flat_map(&LazyHTML.attribute(&1, "id"))
  end

  defp make_admin(%{user: user}) do
    put_admin_emails([String.downcase(user.email)])
    %{scope: Scope.for_user(user)}
  end

  describe "who can open them" do
    test "a visitor is sent to log in", %{conn: conn} do
      assert conn |> get(~p"/admin/messages") |> redirected_to() == ~p"/users/log-in"
      assert conn |> get(~p"/admin/messages/1") |> redirected_to() == ~p"/users/log-in"
    end

    test "a logged-in user who is not an admin gets a 404, as if the pages did not exist" do
      user = user_fixture()
      put_admin_emails(["somebody.else@example.org"])
      conn = build_conn() |> log_in_user(user)
      message = message_fixture()

      assert_error_sent 404, fn -> get(conn, ~p"/admin/messages") end
      assert_error_sent 404, fn -> get(conn, ~p"/admin/messages/#{message.id}") end
    end

    test "a live navigation from another page of the site does not get in either" do
      user = user_fixture()
      put_admin_emails(["somebody.else@example.org"])
      conn = build_conn() |> log_in_user(user)
      message = message_fixture()

      # a redirect ends the page that asked for it, so each try starts from a page of its own
      {:ok, view, _html} = live(conn, ~p"/dashboard")
      assert {:error, {:redirect, %{to: "/"}}} = live_redirect(view, to: ~p"/admin/messages")

      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert {:error, {:redirect, %{to: "/"}}} =
               live_redirect(view, to: ~p"/admin/messages/#{message.id}")

      assert stored(message).status == :new
    end

    test "an address in ADMIN_EMAILS that has not been confirmed is not an admin" do
      user = unconfirmed_user_fixture()
      put_admin_emails([String.downcase(user.email)])
      conn = build_conn() |> log_in_user(user)

      assert_error_sent 404, fn -> get(conn, ~p"/admin/messages") end
    end
  end

  describe "the link in the app" do
    setup [:register_and_log_in_user]

    test "is for the admins only", %{conn: conn, user: user} do
      put_admin_emails(["somebody.else@example.org"])
      {:ok, view, _html} = live(conn, ~p"/dashboard")
      refute has_element?(view, "#nav-messages")
      refute has_element?(view, "#m-messages")

      put_admin_emails([String.downcase(user.email)])
      {:ok, view, _html} = live(conn, ~p"/dashboard")
      assert has_element?(view, ~s(#nav-messages[href="/admin/messages"]))
      assert has_element?(view, ~s(#m-messages[href="/admin/messages"]))

      assert {:error, {:live_redirect, %{to: "/admin/messages"}}} =
               view |> element("#nav-messages") |> render_click()
    end

    test "is highlighted on the pages of the messages", %{conn: conn} = context do
      make_admin(context)
      message = message_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/messages")
      assert has_element?(view, "#nav-messages[aria-current=page]")

      {:ok, view, _html} = live(conn, ~p"/admin/messages/#{message.id}")
      assert has_element?(view, "#nav-messages[aria-current=page]")
    end
  end

  describe "the list" do
    setup [:register_and_log_in_user, :make_admin]

    test "shows the messages newest first, with who wrote them, the kind, the reference and the status",
         %{
           conn: conn
         } do
      old = message_fixture(%{inserted_at: ~U[2026-11-01 09:00:00Z], message: "The first one"})

      new =
        message_fixture(%{
          inserted_at: ~U[2026-11-07 18:30:00Z],
          topic: :problem,
          name: "Asha Rao",
          email: "asha@example.com",
          message: "The second one"
        })

      {:ok, view, _html} = live(conn, ~p"/admin/messages")

      assert row_ids(view) == ["messages-#{new.id}", "messages-#{old.id}"]

      row = "#messages-#{new.id}"
      assert has_element?(view, row, "Asha Rao")
      assert has_element?(view, row, "asha@example.com")
      assert has_element?(view, row, "The second one")
      assert has_element?(view, row, "Problem report")
      assert has_element?(view, row, new.reference)
      assert has_element?(view, row, "New")
      assert has_element?(view, row, "7 Nov 2026, 18:30 UTC")
    end

    test "says how many there are of each status", %{conn: conn} do
      message_fixture(%{status: :new})
      message_fixture(%{status: :new})
      message_fixture(%{status: :read})
      message_fixture(%{status: :resolved})

      {:ok, view, _html} = live(conn, ~p"/admin/messages")

      assert has_element?(view, "#status-all", "4")
      assert has_element?(view, "#status-new", "2")
      assert has_element?(view, "#status-read", "1")
      assert has_element?(view, "#status-resolved", "1")
      assert has_element?(view, "#status-all[aria-current=page]")
    end

    test "shows one status when a chip is clicked, and keeps it in the address", %{conn: conn} do
      unread = message_fixture(%{status: :new})
      resolved = message_fixture(%{status: :resolved})

      {:ok, view, _html} = live(conn, ~p"/admin/messages")
      view |> element("#status-resolved") |> render_click()

      assert_patch(view, "/admin/messages?status=resolved")
      assert row_ids(view) == ["messages-#{resolved.id}"]
      assert has_element?(view, "#status-resolved[aria-current=page]")

      {:ok, view, _html} = live(conn, ~p"/admin/messages?status=new")
      assert row_ids(view) == ["messages-#{unread.id}"]
    end

    test "shows one kind of message when it is chosen", %{conn: conn} do
      problem = message_fixture(%{topic: :problem})
      message_fixture(%{topic: :feedback})

      {:ok, view, _html} = live(conn, ~p"/admin/messages")

      view
      |> form("#message-filters", filters: %{"topic" => "problem"})
      |> render_change()

      assert_patch(view, "/admin/messages?topic=problem")
      assert row_ids(view) == ["messages-#{problem.id}"]
    end

    test "looks for a word in the message, the name, the address and the reference", %{conn: conn} do
      by_words = message_fixture(%{message: "The GST line is missing"})
      by_name = message_fixture(%{name: "Gita Menon"})

      other =
        message_fixture(%{
          message: "Nothing to see here",
          name: "Bilal",
          email: "bilal@example.org"
        })

      {:ok, view, _html} = live(conn, ~p"/admin/messages")

      view |> form("#message-filters", filters: %{"q" => "gst"}) |> render_change()
      assert_patch(view, "/admin/messages?q=gst")
      assert row_ids(view) == ["messages-#{by_words.id}"]

      view |> form("#message-filters", filters: %{"q" => "gita"}) |> render_change()
      assert row_ids(view) == ["messages-#{by_name.id}"]

      view |> form("#message-filters", filters: %{"q" => other.reference}) |> render_change()
      assert row_ids(view) == ["messages-#{other.id}"]

      view |> form("#message-filters", filters: %{"q" => "bilal@"}) |> render_change()
      assert row_ids(view) == ["messages-#{other.id}"]
    end

    test "keeps what was typed in the search box, and the kind, when the page is opened again", %{
      conn: conn
    } do
      message_fixture(%{topic: :problem, message: "The GST line is missing"})

      {:ok, view, _html} = live(conn, ~p"/admin/messages?q=gst&topic=problem")

      assert has_element?(view, ~s(#message-search[value="gst"]))
      assert has_element?(view, ~s(#message-topic option[value=problem][selected]))
    end

    test "says so when nothing matches, or when there is nothing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/messages")
      assert has_element?(view, "#messages-empty", "it is kept here")
      refute has_element?(view, "#messages")

      message_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/messages?q=nothing-like-it")
      assert has_element?(view, "#messages-empty", "Nothing matches")
    end

    test "gives a page at a time", %{conn: conn} do
      for n <- 1..26,
          do: message_fixture(%{inserted_at: DateTime.add(~U[2026-11-01 00:00:00Z], n, :minute)})

      {:ok, view, _html} = live(conn, ~p"/admin/messages")
      assert length(row_ids(view)) == 25
      assert has_element?(view, "#message-pages", "Page 1 of 2, 26 messages")
      refute has_element?(view, "#newer-messages")

      view |> element("#older-messages") |> render_click()
      assert_patch(view, "/admin/messages?page=2")
      assert length(row_ids(view)) == 1
      refute has_element?(view, "#older-messages")

      view |> element("#newer-messages") |> render_click()
      assert_patch(view, "/admin/messages")
      assert length(row_ids(view)) == 25
    end

    test "takes no notice of a filter or a page that is not one", %{conn: conn} do
      message = message_fixture()

      {:ok, view, _html} =
        live(conn, ~p"/admin/messages?status=evil&topic=%3Cscript%3E&page=abc")

      assert row_ids(view) == ["messages-#{message.id}"]

      {:ok, view, _html} = live(conn, ~p"/admin/messages?page=99")
      assert row_ids(view) == ["messages-#{message.id}"]
    end

    test "goes to a message when its row is clicked: the whole row is one link", %{conn: conn} do
      message = message_fixture(%{name: "Asha Rao"})
      {:ok, view, _html} = live(conn, ~p"/admin/messages")

      assert {:error, {:live_redirect, %{to: to}}} =
               view |> element("#messages-#{message.id} a", "Asha Rao") |> render_click()

      assert to == "/admin/messages/#{message.id}"
    end

    test "follows the messages as they arrive and change", %{conn: conn, scope: scope} do
      {:ok, view, _html} = live(conn, ~p"/admin/messages")
      assert has_element?(view, "#messages-empty")

      # one arrives, with the e-mails that follow it
      put_contact_email("owner@example.org")
      {:ok, message} = submit_message()
      wait_for_tasks()

      assert row_ids(view) == ["messages-#{message.id}"]
      assert has_element?(view, "#status-new", "1")

      {:ok, _} = Contact.set_status(scope, message, :resolved)
      assert has_element?(view, "#messages-#{message.id}", "Resolved")
      assert has_element?(view, "#status-resolved", "1")

      {:ok, _} = Contact.delete_message(scope, message)
      assert has_element?(view, "#messages-empty")
    end
  end

  describe "one message" do
    setup [:register_and_log_in_user, :make_admin]

    test "shows what was written, who wrote it, and what the page knew", %{conn: conn} do
      writer = user_fixture()

      message =
        message_fixture(%{
          topic: :change,
          name: "Asha Rao",
          email: "asha@example.com",
          message: "Please add a template for a courier receipt.\nWith the tracking number.",
          locale: "hi-IN",
          page: "/hi-in/fuel-bill-generator",
          user_id: writer.id,
          inserted_at: ~U[2026-11-07 18:30:00Z]
        })

      {:ok, view, _html} = live(conn, ~p"/admin/messages/#{message.id}")

      assert has_element?(view, "h1", message.reference)
      assert has_element?(view, "#message-subtitle", "Change request")
      assert has_element?(view, "#message-subtitle", "7 Nov 2026, 18:30 UTC")
      assert has_element?(view, "#message-body", "Please add a template for a courier receipt.")
      assert has_element?(view, "#message-body", "With the tracking number.")
      assert has_element?(view, "#message-from", "Asha Rao")
      assert has_element?(view, ~s(#message-from a[href="mailto:asha@example.com"]))
      assert has_element?(view, "#message-account", "#{writer.email} (user #{writer.id})")
      assert has_element?(view, "#message-locale", "hi-IN")
      assert has_element?(view, ~s(#message-page a[href="/hi-in/fuel-bill-generator"]))
    end

    test "has no lines for what the message does not have", %{conn: conn} do
      message = message_fixture(%{name: nil, page: nil, locale: nil, user_id: nil})

      {:ok, view, _html} = live(conn, ~p"/admin/messages/#{message.id}")

      refute has_element?(view, "#message-account")
      refute has_element?(view, "#message-page")
      refute has_element?(view, "#message-locale")
    end

    test "says whether the e-mails went out", %{conn: conn} do
      sent = ~U[2026-11-07 18:31:00Z]
      done = message_fixture(%{owner_notified_at: sent, confirmation_sent_at: sent})
      waiting = message_fixture()

      {:ok, view, _html} = live(conn, ~p"/admin/messages/#{done.id}")
      assert has_element?(view, "#message-owner-notified", "Sent 7 Nov 2026, 18:31 UTC")
      assert has_element?(view, "#message-confirmation", "Sent 7 Nov 2026, 18:31 UTC")

      {:ok, view, _html} = live(conn, ~p"/admin/messages/#{waiting.id}")
      assert has_element?(view, "#message-owner-notified", "Not sent")
      assert has_element?(view, "#message-confirmation", "Not sent")
    end

    test "marks a new message as read when it is opened, and leaves the others as they are", %{
      conn: conn
    } do
      unread = message_fixture(%{status: :new})
      resolved = message_fixture(%{status: :resolved})

      {:ok, view, _html} = live(conn, ~p"/admin/messages/#{unread.id}")
      assert has_element?(view, "#message-status", "Read")
      assert stored(unread).status == :read

      {:ok, view, _html} = live(conn, ~p"/admin/messages/#{resolved.id}")
      assert has_element?(view, "#message-status", "Resolved")
      assert stored(resolved).status == :resolved
    end

    test "can be moved to another status, and offers only the others", %{conn: conn} do
      message = message_fixture(%{status: :new})
      {:ok, view, _html} = live(conn, ~p"/admin/messages/#{message.id}")

      # it is read now, so it can be marked unread or resolved
      refute has_element?(view, "#move-to-read")
      assert has_element?(view, "#move-to-new")
      assert has_element?(view, "#move-to-resolved")

      view |> element("#move-to-resolved") |> render_click()
      assert has_element?(view, "#message-status", "Resolved")
      assert stored(message).status == :resolved
      refute has_element?(view, "#move-to-resolved")

      view |> element("#move-to-new") |> render_click()
      assert has_element?(view, "#message-status", "New")
      assert stored(message).status == :new
    end

    test "ignores a status that is not one", %{conn: conn} do
      message = message_fixture(%{status: :read})
      {:ok, view, _html} = live(conn, ~p"/admin/messages/#{message.id}")

      render_hook(view, "status", %{"status" => "spam"})

      assert has_element?(view, "#message-status", "Read")
      assert stored(message).status == :read
    end

    test "has a button that opens a message to the sender with the reference in its subject", %{
      conn: conn
    } do
      message = message_fixture(%{email: "asha@example.com"})
      {:ok, view, _html} = live(conn, ~p"/admin/messages/#{message.id}")

      href =
        view
        |> element("#reply-link")
        |> render()
        |> LazyHTML.from_fragment()
        |> LazyHTML.attribute("href")

      assert [mailto] = href

      assert %URI{scheme: "mailto", path: "asha@example.com", query: query} = URI.parse(mailto)

      assert URI.decode_query(query) == %{
               "subject" => "Re: Your message to QuickSlips (#{message.reference})"
             }
    end

    test "can be deleted for good, which goes back to the list", %{conn: conn} do
      message = message_fixture()
      keep = message_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/messages/#{message.id}")

      {:ok, _list, html} =
        view
        |> element("#delete-message")
        |> render_click()
        |> follow_redirect(conn, ~p"/admin/messages")

      assert html =~ "The message was deleted."
      assert Repo.get(Message, message.id) == nil
      assert Repo.get(Message, keep.id)
    end

    test "asks before it deletes", %{conn: conn} do
      message = message_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/messages/#{message.id}")

      assert has_element?(view, "#delete-message[data-confirm]")
    end

    test "has no page for a message that is not there", %{conn: conn} do
      assert_error_sent 404, fn -> get(conn, ~p"/admin/messages/0") end
    end

    test "leaves the page when the message is deleted somewhere else", %{conn: conn, scope: scope} do
      message = message_fixture()
      {:ok, view, _html} = live(conn, ~p"/admin/messages/#{message.id}")

      {:ok, _} = Contact.delete_message(scope, message)

      assert_redirect(view, "/admin/messages")
    end

    test "shows the e-mails as they go out, a moment after the message is kept", %{conn: conn} do
      put_contact_email("owner@example.org")
      {:ok, message} = submit_message()
      {:ok, view, _html} = live(conn, ~p"/admin/messages/#{message.id}")

      wait_for_tasks()

      assert has_element?(view, "#message-owner-notified", "Sent")
      assert has_element?(view, "#message-confirmation", "Sent")
      refute has_element?(view, "#message-owner-notified", "Not sent")
    end
  end

  # A message that comes through the form's own way in, with the e-mails that follow it.
  defp submit_message do
    {:ok, message} =
      Contact.review(%{
        "topic" => "problem",
        "name" => "Asha Rao",
        "email" => "asha@example.com",
        "message" => "The fuel bill has no line for GST."
      })

    Contact.submit(message, %{
      user: nil,
      locale: QuickSlips.Locales.default(),
      page: nil,
      site_url: "https://quickslips.example"
    })
  end
end
