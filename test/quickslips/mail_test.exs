defmodule QuickSlips.MailTest do
  # The sender and the contact address are settings of the whole application, so these tests run one at a time.
  use ExUnit.Case, async: false

  import QuickSlips.SiteHelpers
  import Swoosh.TestAssertions

  alias QuickSlips.Mail
  alias QuickSlips.Mail.Letter

  @url "https://quickslips.example/users/log-in/TOKEN"

  setup do
    previous = Application.fetch_env!(:quickslips, :mail_from)
    Application.put_env(:quickslips, :mail_from, "hello@mail.example.test")
    on_exit(fn -> Application.put_env(:quickslips, :mail_from, previous) end)
    put_contact_email(nil)
    :ok
  end

  defp letter(extra \\ []) do
    struct!(
      %Letter{
        language: "en",
        subject: "Your QuickSlips log-in link",
        heading: "Log in to QuickSlips",
        blocks: [{:text, "Hello,"}, {:button, "Log in", @url}],
        footer: ["You are receiving this email because person@example.com was used."]
      },
      extra
    )
  end

  defp deliver!(letter \\ letter(), opts \\ []) do
    {:ok, email} =
      Mail.deliver(
        letter,
        "person@example.test",
        [site_url: "https://quickslips.example"] ++ opts
      )

    email
  end

  test "sends the HTML and the text of the letter, from the sender of the site, to the address" do
    email = deliver!()

    assert email.from == {"QuickSlips", "hello@mail.example.test"}
    assert email.to == [{"", "person@example.test"}]
    assert email.subject == "Your QuickSlips log-in link"
    assert email.html_body =~ ~s(href="#{@url}")
    assert email.text_body =~ @url
    assert email.html_body =~ "Log in to QuickSlips"
    assert email.text_body =~ "Log in to QuickSlips"

    assert_email_sent(subject: "Your QuickSlips log-in link", to: {nil, "person@example.test"})
  end

  test "says in its headers that a program wrote it, so that robots do not answer" do
    email = deliver!()

    assert email.headers["Auto-Submitted"] == "auto-generated"
    assert email.headers["X-Auto-Response-Suppress"] == "OOF, AutoReply"
  end

  test "has a Message-ID on the domain of the sender that never repeats, and a Date in UTC" do
    first = deliver!()
    second = deliver!()

    assert first.headers["Message-ID"] =~ ~r/\A<[0-9a-f]{32}@mail\.example\.test>\z/
    refute first.headers["Message-ID"] == second.headers["Message-ID"]

    assert first.headers["Date"] =~
             ~r/\A(Mon|Tue|Wed|Thu|Fri|Sat|Sun), \d\d (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d{4} \d\d:\d\d:\d\d \+0000\z/
  end

  test "has none of the headers of advertising: it is an e-mail that the person asked for" do
    email = deliver!()

    for header <- ["List-Unsubscribe", "List-Unsubscribe-Post", "Precedence", "X-Mailer"] do
      refute Map.has_key?(email.headers, header), "has #{header}"
    end
  end

  test "has no Reply-To unless one is given" do
    assert deliver!().reply_to == nil
    assert deliver!(letter(), reply_to: "owner@example.org").reply_to == {"", "owner@example.org"}

    assert deliver!(letter(), reply_to: {"Asha Rao", "asha@example.com"}).reply_to ==
             {"Asha Rao", "asha@example.com"}
  end

  test "says in the foot that a reply is read, when it is asked to" do
    without = deliver!()
    refute without.text_body =~ "Questions?"
    refute without.html_body =~ "Questions?"

    with = deliver!(letter(), reply_to: "owner@example.org", invite_reply?: true)
    assert with.text_body =~ "Questions? Reply to this email and a person will read it."
    assert with.html_body =~ "Questions? Reply to this email and a person will read it."
  end

  test "points the logo and the foot to the address of the site it is given" do
    email = deliver!()

    assert email.html_body =~ ~s(src="https://quickslips.example/images/email/logo.png")
    assert email.text_body =~ "QuickSlips · https://quickslips.example"
    assert email.text_body =~ "Privacy: https://quickslips.example/privacy"
    assert email.text_body =~ "Terms: https://quickslips.example/terms"
  end

  test "uses the address of the endpoint for them when it is not given" do
    {:ok, email} = Mail.deliver(letter(), "person@example.test")

    assert email.html_body =~ ~s(src="#{QuickSlipsWeb.Endpoint.url()}/images/email/logo.png")
  end

  test "offers the contact page only when the site has an address to be contacted at" do
    refute deliver!().text_body =~ "Contact:"

    put_contact_email("owner@example.org")
    email = deliver!()
    assert email.text_body =~ "Contact: https://quickslips.example/contact"
    assert email.html_body =~ ~s(href="https://quickslips.example/contact")
  end

  test "writes what goes around the letter in the language of the letter" do
    email = deliver!(letter(language: "es"), reply_to: "owner@example.org", invite_reply?: true)

    assert email.html_body =~ ~s(<html lang="es")
    assert email.text_body =~ "Facturas y recibos, listos en segundos"
    assert email.text_body =~ "Privacidad: https://quickslips.example/privacy"
    assert email.text_body =~ "¿Tienes preguntas? Responde a este correo y una persona lo leerá."
  end

  test "renders both versions without sending anything" do
    assert %{html: html, text: text} =
             Mail.render(letter(), site_url: "https://quickslips.example")

    assert html =~ "Log in to QuickSlips"
    assert text =~ "Log in to QuickSlips"
    refute_email_sent()
  end

  test "gives back the error of the mail provider" do
    previous = Application.fetch_env!(:quickslips, QuickSlips.Mailer)
    on_exit(fn -> Application.put_env(:quickslips, QuickSlips.Mailer, previous) end)
    Application.put_env(:quickslips, QuickSlips.Mailer, adapter: QuickSlips.FailingMailAdapter)

    assert {:error, :provider_down} = Mail.deliver(letter(), "person@example.test")
  end
end
