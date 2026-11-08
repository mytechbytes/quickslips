defmodule QuickSlips.ContactTest do
  # The contact address, the ceilings and the admins are settings of the whole application, so these tests run one
  # at a time.
  use QuickSlips.DataCase, async: false

  import ExUnit.CaptureLog
  import QuickSlips.AccountsFixtures
  import QuickSlips.SiteHelpers
  import QuickSlips.TaskHelpers

  alias QuickSlips.Accounts.Scope
  alias QuickSlips.Contact
  alias QuickSlips.Contact.Message
  alias QuickSlips.Locales
  alias QuickSlips.Quota

  # What the contact form does with a message: what is checked of it, what is kept, the two e-mails that follow, what
  # stops a mailbox from being flooded, and what the owner can do with the messages. The page of the form is tested
  # with `QuickSlipsWeb.ContactLiveTest` and the pages of the owner with `QuickSlipsWeb.Admin.MessageLiveTest`.

  # What config/config.exs sets, read before any test changes it.
  @configured_limits Application.compile_env(:quickslips, :contact_limits)

  setup do
    put_contact_email("owner@example.org")
    put_contact_limits(user: 2, all: 3, to: 2)
    # a task that is still running when a test ends would find its database connection gone
    on_exit(&wait_for_tasks/0)
    :ok
  end

  defp attrs(extra \\ %{}) do
    Map.merge(
      %{
        "topic" => "problem",
        "name" => "Asha Rao",
        "email" => "asha@example.com",
        "message" => "The fuel bill has no line for GST."
      },
      extra
    )
  end

  defp message!(extra \\ %{}) do
    {:ok, message} = Contact.review(attrs(extra))
    message
  end

  # What the page tells the context of the visit.
  defp context(extra \\ %{}) do
    Map.merge(
      %{
        user: nil,
        locale: Locales.fetch!("en-in"),
        page: nil,
        site_url: "https://quickslips.example"
      },
      extra
    )
  end

  # Keeps a message and lets the e-mails that follow it go out.
  defp submit!(extra_attrs \\ %{}, extra_context \\ %{}) do
    assert {:ok, saved} = Contact.submit(message!(extra_attrs), context(extra_context))
    wait_for_tasks()
    saved
  end

  # `%{field => [what is wrong]}` for a message that is refused.
  defp errors(extra) do
    {:error, changeset} = Contact.review(attrs(extra))
    errors_on(changeset)
  end

  # Every e-mail that was sent since the last call, oldest first.
  defp emails(found \\ []) do
    receive do
      {:email, email} -> emails([email | found])
    after
      0 -> Enum.reverse(found)
    end
  end

  defp to_owner(emails), do: Enum.find(emails, &(&1.to == [{"", "owner@example.org"}]))
  defp to_sender(emails), do: Enum.find(emails, &(&1.to != [{"", "owner@example.org"}]))

  defp stored(%Message{id: id}), do: Repo.get!(Message, id)

  # The value of a line of the e-mail to the owner, like "Topic:      Problem report" (the width of the column of
  # labels is not what is tested).
  defp field(body, label) do
    case Regex.run(~r/^#{label}:[ ]+(.*)$/m, body) do
      [_line, value] -> value
      nil -> nil
    end
  end

  defp admin_scope do
    user = user_fixture()
    put_admin_emails([String.downcase(user.email)])
    Scope.for_user(user)
  end

  describe "review/1" do
    test "takes a complete message, with the topic as one of the known kinds" do
      assert {:ok, %Message{} = message} = Contact.review(attrs())

      assert %{topic: :problem, name: "Asha Rao", email: "asha@example.com"} = message
      assert message.message == "The fuel bill has no line for GST."
    end

    test "knows five kinds of message, and starts with feedback" do
      assert Message.topics() == [:change, :feedback, :problem, :complaint, :other]
      assert %Message{}.topic == :feedback

      for topic <- Message.topics() do
        assert {:ok, %Message{topic: ^topic}} = Contact.review(attrs(%{"topic" => "#{topic}"}))
      end
    end

    test "does not know any other kind" do
      assert %{topic: ["is invalid"]} = errors(%{"topic" => "refund"})
    end

    test "needs an address and a message, and not a name" do
      errors = errors(%{"email" => "", "message" => "   "})
      assert "can't be blank" in errors.email
      assert "can't be blank" in errors.message

      assert {:ok, %Message{name: nil}} = Contact.review(attrs(%{"name" => ""}))
    end

    test "keeps the name to one line and the address free of spaces" do
      assert {:ok, %Message{name: "Asha Rao", email: "asha@example.com"}} =
               Contact.review(
                 attrs(%{"name" => "  Asha \n\t Rao  ", "email" => "  asha@example.com "})
               )

      assert {:ok, %Message{name: nil}} = Contact.review(attrs(%{"name" => " \n "}))
    end

    test "refuses an address that is not one, or that could break the header of an e-mail" do
      for bad <- [
            "asha",
            "asha@",
            "@example.com",
            "asha@example",
            "asha example@example.com",
            "asha@example.com, boss@example.com",
            "asha@example.com;boss@example.com",
            "Asha <asha@example.com>",
            "\"asha\"@example.com",
            "asha@exa(mple).com",
            "asha@example.com\nBcc: boss@example.com"
          ] do
        assert %{email: ["has invalid format"]} = errors(%{"email" => bad}), inspect(bad)
      end

      for good <- [
            "asha@example.com",
            "asha.rao+bills@mail.example.co.in",
            "a_b-c@sub.example.org"
          ] do
        assert {:ok, _} = Contact.review(attrs(%{"email" => good})), good
      end
    end

    test "wants a message that says something, and not a novel" do
      assert %{message: ["should be at least 5 character(s)"]} = errors(%{"message" => "Hi"})
      assert {:ok, _} = Contact.review(attrs(%{"message" => "Great!"}))
      # short for a person who writes in Chinese or Japanese is still a message
      assert {:ok, _} = Contact.review(attrs(%{"message" => "增加一个模板"}))

      assert {:ok, _} = Contact.review(attrs(%{"message" => String.duplicate("a", 4000)}))

      assert %{message: ["should be at most 4000 character(s)"]} =
               errors(%{"message" => String.duplicate("a", 4001)})
    end

    test "limits the name and the address" do
      assert %{name: ["should be at most 100 character(s)"]} =
               errors(%{"name" => String.duplicate("n", 101)})

      long = String.duplicate("a", 150) <> "@example.com"
      assert %{email: ["should be at most 160 character(s)"]} = errors(%{"email" => long})
    end

    test "has nothing in it that the form could set but the kind, the name, the address and the words" do
      {:ok, message} =
        Contact.review(
          attrs(%{
            "reference" => "FAKE-FAKE",
            "status" => "resolved",
            "user_id" => "1",
            "locale" => "xx",
            "page" => "/somewhere"
          })
        )

      assert %{reference: nil, status: :new, user_id: nil, locale: nil, page: nil} = message
    end
  end

  describe "available?/0" do
    test "is whether there is an address to tell" do
      assert Contact.available?()

      put_contact_email(nil)
      refute Contact.available?()

      put_contact_email("   ")
      refute Contact.available?()
    end
  end

  describe "submit/2 keeps the message" do
    test "with what was written, what the page knew, and a reference" do
      user = user_fixture()

      saved =
        submit!(%{"topic" => "complaint"}, %{
          user: user,
          locale: Locales.fetch!("es-es"),
          page: "/es-es/generador-de-factura-de-gasolina"
        })

      kept = stored(saved)

      assert %{
               topic: :complaint,
               name: "Asha Rao",
               email: "asha@example.com",
               message: "The fuel bill has no line for GST.",
               locale: "es-ES",
               page: "/es-es/generador-de-factura-de-gasolina",
               status: :new
             } = kept

      assert kept.user_id == user.id
      assert kept.reference =~ ~r/\A[A-Z2-7]{4}-[A-Z2-7]{4}\z/
      assert kept.reference == saved.reference
    end

    test "without an account, a page or a name, when there were none" do
      saved = submit!(%{"name" => ""})

      assert %{user_id: nil, page: nil, name: nil, locale: "en-IN"} = stored(saved)
    end

    test "with a reference of its own for each" do
      references = for _ <- 1..3, do: submit!(%{}, %{user: nil}).reference

      assert references == Enum.uniq(references)
    end

    test "and keeps it when the account that wrote it is deleted" do
      user = user_fixture()
      saved = submit!(%{}, %{user: user})

      Repo.delete!(user)

      assert %{user_id: nil, email: "asha@example.com"} = stored(saved)
    end

    test "is told it cannot when there is no address to tell, and keeps nothing" do
      put_contact_email(nil)

      assert {:error, :unavailable} = Contact.submit(message!(), context())
      assert Repo.aggregate(Message, :count) == 0
      refute_received {:email, _}
    end

    test "keeps nothing of a message that has the robot trap filled in, and gives a reference all the same" do
      assert {:ok, %Message{reference: reference}} =
               Contact.submit(message!(%{"website" => "https://cheap-pills.example"}), context())

      wait_for_tasks()
      assert reference =~ ~r/\A[A-Z2-7]{4}-[A-Z2-7]{4}\z/
      assert Repo.aggregate(Message, :count) == 0
      refute_received {:email, _}
      # and it did not use up a message of the day
      assert Quota.remaining("contact:all", 3) == 3
    end

    test "a trap with only spaces in it is not a robot" do
      saved = submit!(%{"website" => "   "})

      assert stored(saved).email == "asha@example.com"
    end

    test "never keeps what is in the robot trap" do
      saved = submit!(%{"website" => "   "})

      assert %{website: nil} = stored(saved)
    end

    test "gives the count of the day back, and says so, when it cannot be kept" do
      # a name longer than the column: the form would not let it through, and the database does not either
      too_long = %{message!() | name: String.duplicate("n", 300)}
      user = user_fixture()

      log =
        capture_log(fn ->
          assert {:error, :storage} = Contact.submit(too_long, context(%{user: user}))
        end)

      assert log =~ "could not be kept"
      assert Repo.aggregate(Message, :count) == 0
      assert Quota.remaining("contact:u:#{user.id}", 2) == 2
      assert Quota.remaining("contact:all", 3) == 3
    end
  end

  describe "the e-mail to the owner" do
    test "tells them, with the sender's address to answer to" do
      saved = submit!()

      email = emails() |> to_owner()
      assert email.reply_to == {"Asha Rao", "asha@example.com"}
      assert email.from == {"QuickSlips", Application.fetch_env!(:quickslips, :mail_from)}
      assert email.subject == "[QuickSlips] Problem report: The fuel bill has no line for GST."

      assert field(email.text_body, "Reference") == saved.reference
      assert field(email.text_body, "Topic") == "Problem report"
      assert field(email.text_body, "From") == "Asha Rao <asha@example.com>"
      assert email.text_body =~ "The fuel bill has no line for GST."
      assert email.text_body =~ "Reply to this e-mail to answer the sender."
    end

    test "has a link to the message in the pages of the owner" do
      saved = submit!()

      body = emails() |> to_owner() |> Map.fetch!(:text_body)
      assert field(body, "Open") == "https://quickslips.example/admin/messages/#{saved.id}"
    end

    test "says what the page knew: the account, the language and country, the page" do
      user = user_fixture()

      submit!(%{}, %{
        user: user,
        locale: Locales.fetch!("es-es"),
        page: "/es-es/generador-de-factura-de-gasolina"
      })

      body = emails() |> to_owner() |> Map.fetch!(:text_body)
      assert field(body, "Account") == "#{user.email} (user #{user.id})"
      assert field(body, "Language") == "es-ES"

      assert field(body, "Page") ==
               "https://quickslips.example/es-es/generador-de-factura-de-gasolina"
    end

    test "has no lines for what it was not told" do
      submit!()

      body = emails() |> to_owner() |> Map.fetch!(:text_body)
      refute body =~ "Account:"
      refute body =~ "Page:"
    end

    test "answers to the bare address when there is no name" do
      submit!(%{"name" => ""})

      email = emails() |> to_owner()
      assert email.reply_to == {"", "asha@example.com"}
      assert field(email.text_body, "From") == "asha@example.com"
    end

    test "leaves out of the name what could end it early in the header" do
      submit!(%{"name" => ~s(Asha "the <boss> \\ Rao)})

      assert {"Asha the boss Rao", "asha@example.com"} =
               emails() |> to_owner() |> Map.fetch!(:reply_to)
    end

    test "puts the start of the message in the subject, on one line, cut at a word and not too long" do
      text =
        "Please add a template for a\ncourier receipt in Hindi, with the tracking number and the weight"

      submit!(%{"topic" => "change", "message" => text})

      subject = emails() |> to_owner() |> Map.fetch!(:subject)

      assert subject ==
               "[QuickSlips] Change request: Please add a template for a courier receipt in Hindi, with…"

      refute subject =~ "\n"
    end

    test "keeps the first 60 characters of a message that has no spaces to cut at" do
      submit!(%{"message" => String.duplicate("发", 100)})

      assert emails() |> to_owner() |> Map.fetch!(:subject) ==
               "[QuickSlips] Problem report: " <> String.duplicate("发", 60) <> "…"
    end

    test "writes the subject in the language of the message, which the mail carries as UTF-8" do
      submit!(%{"message" => "पेट्रोल बिल में GST की लाइन नहीं है"})

      assert emails() |> to_owner() |> Map.fetch!(:subject) ==
               "[QuickSlips] Problem report: पेट्रोल बिल में GST की लाइन नहीं है"
    end

    test "says every kind of message in its own words" do
      put_contact_limits(user: 10, all: 10, to: 10)

      labels = %{
        change: "Change request",
        feedback: "Feedback",
        problem: "Problem report",
        complaint: "Complaint or dispute",
        other: "Other"
      }

      for {topic, label} <- labels do
        submit!(%{"topic" => "#{topic}"})
        assert emails() |> to_owner() |> Map.fetch!(:text_body) |> field("Topic") == label
      end
    end

    test "is noted on the message, once it went" do
      saved = submit!()

      assert %DateTime{} = stored(saved).owner_notified_at
    end
  end

  describe "the e-mail to the sender" do
    test "tells them that the message arrived and what its reference is, and answers to the owner" do
      saved = submit!()

      email = emails() |> to_sender()
      assert email.to == [{"", "asha@example.com"}]
      assert email.from == {"QuickSlips", Application.fetch_env!(:quickslips, :mail_from)}
      assert email.reply_to == {"", "owner@example.org"}
      assert email.subject == "Your message to QuickSlips (#{saved.reference})"

      assert email.text_body =~ "Reference: #{saved.reference}"
      assert email.text_body =~ "Topic: Report a problem"
      assert email.text_body =~ ~r/Received: \d{4}-\d\d-\d\d \d\d:\d\d UTC/
      assert email.text_body =~ "If you did not send this message, please ignore this e-mail."
      assert email.text_body =~ "QuickSlips · https://quickslips.example"
    end

    test "greets the sender by name, and gives their message back" do
      submit!(%{
        "name" => "Asha Rao",
        "message" => "The fuel bill has no line for GST.\nPlease add one."
      })

      email = emails() |> to_sender()
      assert email.text_body =~ "Hello Asha Rao,"

      assert email.text_body =~
               "Your message:\n----------------------------------------\nThe fuel bill has no line for GST.\nPlease add one.\n"

      # the name is not in the subject or the header, and the address is the one typed
      refute email.subject =~ "Asha"
      assert email.to == [{"", "asha@example.com"}]
    end

    test "greets without a name when there is none" do
      submit!(%{"name" => ""})

      assert emails() |> to_sender() |> Map.fetch!(:text_body) =~ "Hello,\n"
    end

    test "is in the language of the page" do
      submit!(%{}, %{locale: Locales.fetch!("es-es")})

      email = emails() |> to_sender()
      assert email.subject =~ ~r/\ATu mensaje a QuickSlips \([A-Z2-7]{4}-[A-Z2-7]{4}\)\z/
      assert email.text_body =~ "Gracias por escribir a QuickSlips."
      assert email.text_body =~ "Tema: Informar de un problema"
      refute email.text_body =~ "Thank you for writing"
    end

    test "is noted on the message, once it went" do
      saved = submit!()

      assert %DateTime{} = stored(saved).confirmation_sent_at
    end

    test "is sent to one address only so many times in a day, and the message is kept all the same" do
      put_contact_limits(user: 10, all: 10, to: 2)

      first = submit!()
      second = submit!()
      third = submit!()

      sent = emails() |> Enum.filter(&(&1.to == [{"", "asha@example.com"}]))
      assert length(sent) == 2

      assert %DateTime{} = stored(first).confirmation_sent_at
      assert %DateTime{} = stored(second).confirmation_sent_at
      assert stored(third).confirmation_sent_at == nil
      # the owner was told of all three
      assert %DateTime{} = stored(third).owner_notified_at
    end

    test "counts an address the same in capitals, and keeps the address itself out of the counters" do
      put_contact_limits(user: 10, all: 10, to: 1)

      submit!(%{"email" => "Asha@Example.com"})
      third = submit!(%{"email" => "asha@example.com"})

      assert stored(third).confirmation_sent_at == nil

      keys = Repo.all(from c in QuickSlips.Quota.Counter, select: c.key)
      assert Enum.any?(keys, &String.starts_with?(&1, "contact:to:"))
      refute Enum.any?(keys, &(String.downcase(&1) =~ "asha"))
    end
  end

  describe "the ceilings of a day" do
    test "a user can send as many messages as the ceiling says, and then no more" do
      user = user_fixture()

      assert {:ok, _} = Contact.submit(message!(), context(%{user: user}))
      assert {:ok, _} = Contact.submit(message!(), context(%{user: user}))
      assert {:error, :limit} = Contact.submit(message!(), context(%{user: user}))

      wait_for_tasks()
      assert Repo.aggregate(Message, :count) == 2
    end

    test "another user is not held back by the first" do
      first = user_fixture()
      second = user_fixture()

      for _ <- 1..2, do: assert({:ok, _} = Contact.submit(message!(), context(%{user: first})))
      assert {:error, :limit} = Contact.submit(message!(), context(%{user: first}))

      assert {:ok, _} = Contact.submit(message!(), context(%{user: second}))
    end

    test "the site has a ceiling too, for everybody together" do
      for _ <- 1..3, do: assert({:ok, _} = Contact.submit(message!(), context()))
      assert {:error, :limit} = Contact.submit(message!(), context())

      # a logged-in user is stopped by it as well, and is not charged for the message that did not go
      user = user_fixture()
      assert {:error, :limit} = Contact.submit(message!(), context(%{user: user}))
      assert Quota.remaining("contact:u:#{user.id}", 2) == 2
    end

    test "counts a message once for the user and once for the site" do
      user = user_fixture()
      assert {:ok, _} = Contact.submit(message!(), context(%{user: user}))

      assert Quota.remaining("contact:u:#{user.id}", 2) == 1
      assert Quota.remaining("contact:all", 3) == 2
    end

    test "the ceilings in the configuration are 5 for a user, 100 for the site and 3 confirmations to an address" do
      assert @configured_limits == [user: 5, all: 100, to: 3]
    end

    test "falls back on those when the configuration says nothing of one" do
      put_contact_limits([])
      user = user_fixture()

      for _ <- 1..5, do: assert({:ok, _} = Contact.submit(message!(), context(%{user: user})))
      assert {:error, :limit} = Contact.submit(message!(), context(%{user: user}))
    end
  end

  describe "when the mail cannot be sent" do
    setup do
      previous = Application.fetch_env!(:quickslips, QuickSlips.Mailer)
      on_exit(fn -> Application.put_env(:quickslips, QuickSlips.Mailer, previous) end)
      :ok
    end

    test "the message is kept all the same, and the owner can see that nobody was told" do
      Application.put_env(:quickslips, QuickSlips.Mailer, adapter: QuickSlips.FailingMailAdapter)

      log =
        capture_log(fn ->
          assert {:ok, saved} = Contact.submit(message!(), context())
          wait_for_tasks()

          assert %{
                   owner_notified_at: nil,
                   confirmation_sent_at: nil,
                   message: "The fuel bill" <> _
                 } =
                   stored(saved)
        end)

      assert log =~ "to the owner about a contact message was not sent: :provider_down"
      assert log =~ "to the sender about a contact message was not sent: :provider_down"
      # and the log does not carry what the visitor wrote
      refute log =~ "GST"
      refute log =~ "asha@example.com"
    end

    test "says the same when the provider raises an error instead of answering with one" do
      Application.put_env(:quickslips, QuickSlips.Mailer,
        adapter: QuickSlips.FailingMailAdapter,
        mode: :raise
      )

      log =
        capture_log(fn ->
          assert {:ok, saved} = Contact.submit(message!(), context())
          wait_for_tasks()
          assert %{owner_notified_at: nil} = stored(saved)
        end)

      assert log =~ "the mail provider crashed"
    end

    test "a message is not lost, and not counted twice, when only the e-mail to the owner fails" do
      Application.put_env(:quickslips, QuickSlips.Mailer,
        adapter: QuickSlips.FailingMailAdapter,
        mode: {:fail_to, "owner@example.org"}
      )

      capture_log(fn ->
        assert {:ok, saved} = Contact.submit(message!(), context())
        wait_for_tasks()

        kept = stored(saved)
        assert kept.owner_notified_at == nil
        assert %DateTime{} = kept.confirmation_sent_at
      end)

      assert Quota.remaining("contact:all", 3) == 2
    end
  end

  describe "for the owner" do
    test "lists the messages, newest first, with how many there are" do
      scope = admin_scope()
      put_contact_limits(user: 10, all: 10, to: 10)
      old = submit!(%{"message" => "The first message"})
      new = submit!(%{"message" => "The second message"})

      assert %{messages: [first, second], total: 2, page: 1, pages: 1} =
               Contact.list_messages(scope)

      assert [first.id, second.id] == [new.id, old.id]
    end

    test "can be told to list one status, one kind, or the ones that have a word in them" do
      scope = admin_scope()
      put_contact_limits(user: 10, all: 10, to: 10)

      problem = submit!(%{"topic" => "problem", "message" => "The GST line is missing"})
      feedback = submit!(%{"topic" => "feedback", "message" => "Lovely little tool"})
      {:ok, _} = Contact.set_status(scope, feedback, :resolved)

      ids = fn opts ->
        scope |> Contact.list_messages(opts) |> Map.fetch!(:messages) |> Enum.map(& &1.id)
      end

      assert ids.(status: :new) == [problem.id]
      assert ids.(status: :resolved) == [feedback.id]
      assert ids.(topic: :feedback) == [feedback.id]
      assert ids.(search: "gst") == [problem.id]
      assert ids.(search: "  LOVELY ") == [feedback.id]
      assert ids.(search: "gst", topic: :feedback) == []
      assert ids.(search: "") |> length() == 2
    end

    test "finds a message by its reference, its address or its name" do
      scope = admin_scope()
      put_contact_limits(user: 10, all: 10, to: 10)
      a = submit!(%{"name" => "Asha Rao", "email" => "asha@example.com"})
      b = submit!(%{"name" => "Bilal Khan", "email" => "bilal@example.org"})

      ids = fn term ->
        scope |> Contact.list_messages(search: term) |> Map.fetch!(:messages) |> Enum.map(& &1.id)
      end

      assert ids.(a.reference) == [a.id]
      assert ids.(String.downcase(b.reference)) == [b.id]
      assert ids.("bilal@") == [b.id]
      assert ids.("Asha R") == [a.id]
    end

    test "takes % and _ in a search for what they are" do
      scope = admin_scope()
      put_contact_limits(user: 10, all: 10, to: 10)
      percent = submit!(%{"message" => "The tax is 18% not 12%"})
      submit!(%{"message" => "Nothing of the kind"})

      assert [%{id: id}] = Contact.list_messages(scope, search: "18%").messages
      assert id == percent.id
      assert Contact.list_messages(scope, search: "%").total == 1
      assert Contact.list_messages(scope, search: "_").total == 0
    end

    test "gives a page at a time, and stays within the pages there are" do
      scope = admin_scope()
      put_contact_limits(user: 10, all: 10, to: 10)
      for n <- 1..5, do: submit!(%{"message" => "Message number #{n}"})

      assert %{total: 5, pages: 3, page: 1, messages: [_, _]} =
               Contact.list_messages(scope, per_page: 2)

      assert %{page: 3, messages: [_]} = Contact.list_messages(scope, per_page: 2, page: 3)
      assert %{page: 3} = Contact.list_messages(scope, per_page: 2, page: 99)
      assert %{page: 1} = Contact.list_messages(scope, per_page: 2, page: 0)

      assert %{total: 0, pages: 1, page: 1, messages: []} =
               Contact.list_messages(scope, search: "nothing like it")
    end

    test "counts the messages by status" do
      scope = admin_scope()
      put_contact_limits(user: 10, all: 10, to: 10)
      assert %{all: 0, new: 0, read: 0, resolved: 0} = Contact.count_messages(scope)

      one = submit!()
      two = submit!()
      submit!()
      {:ok, _} = Contact.set_status(scope, one, :read)
      {:ok, _} = Contact.set_status(scope, two, :resolved)

      assert %{all: 3, new: 1, read: 1, resolved: 1} = Contact.count_messages(scope)
    end

    test "gets a message with the account that wrote it, and says when there is none" do
      scope = admin_scope()
      writer = user_fixture()
      saved = submit!(%{}, %{user: writer})

      assert %Message{user: %{id: id}} = Contact.get_message!(scope, saved.id)
      assert id == writer.id
      assert_raise Ecto.NoResultsError, fn -> Contact.get_message!(scope, 0) end
    end

    test "can say where a message stands, and delete it for good" do
      scope = admin_scope()
      saved = submit!()

      assert {:ok, %Message{status: :read}} = Contact.set_status(scope, saved, :read)
      assert stored(saved).status == :read

      assert {:ok, _} = Contact.delete_message(scope, saved)
      assert Repo.get(Message, saved.id) == nil
    end

    test "can be told when a message comes, changes or goes" do
      scope = admin_scope()
      :ok = Contact.subscribe_messages(scope)

      %{id: id} = submit!()
      assert_receive {:created, %Message{id: ^id}}
      # and the e-mails that went out
      assert_receive {:updated, %Message{id: ^id, owner_notified_at: %DateTime{}}}

      {:ok, _} = Contact.set_status(scope, stored(%Message{id: id}), :resolved)
      assert_receive {:updated, %Message{id: ^id, status: :resolved}}

      {:ok, _} = Contact.delete_message(scope, stored(%Message{id: id}))
      assert_receive {:deleted, %Message{id: ^id}}
    end

    test "is for the admins only: anybody else is refused by the context itself" do
      saved = submit!()
      user = user_fixture()
      put_admin_emails(["somebody.else@example.org"])
      scope = Scope.for_user(user)

      for call <- [
            fn -> Contact.list_messages(scope) end,
            fn -> Contact.count_messages(scope) end,
            fn -> Contact.get_message!(scope, saved.id) end,
            fn -> Contact.set_status(scope, saved, :read) end,
            fn -> Contact.delete_message(scope, saved) end,
            fn -> Contact.subscribe_messages(scope) end
          ] do
        assert_raise ArgumentError, ~r/only an admin/, call
      end

      assert stored(saved).status == :new
    end

    test "is not for a user who is an admin by address but has not confirmed it" do
      user = unconfirmed_user_fixture()
      put_admin_emails([String.downcase(user.email)])

      assert_raise ArgumentError, fn -> Contact.list_messages(Scope.for_user(user)) end
    end
  end
end
