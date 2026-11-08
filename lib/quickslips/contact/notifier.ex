defmodule QuickSlips.Contact.Notifier do
  @moduledoc """
  The two e-mails that a message from the contact form causes.

  *To the owner* (`deliver_to_owner/3`): it comes from the site's own address (`MAIL_FROM`, which the mail provider
  has agreed to send for) and has the sender's address as Reply-To, so answering it from the mailbox answers the
  visitor. The owner reads it, so it is in English whatever the language of the page was.

  *To the sender* (`deliver_confirmation/3`): in the language of the page, to greet them by name, say that the
  message arrived, what its reference is, and to give their words back. The address may be somebody else's, so this
  is limited (Turnstile for everybody, and a few confirmations a day to one address); the e-mail says to ignore it
  if it was not sent by them. Its Reply-To is the owner's, so an answer to it is read.
  """
  use Gettext, backend: QuickSlipsWeb.Gettext

  import Swoosh.Email

  alias QuickSlips.Contact.{Message, Topic}
  alias QuickSlips.Mailer

  @doc """
  Sends `message` to `to`, the owner. `context` says what the form knew besides the message: `:user` (who was logged
  in, or nothing) and `:site_url` (the address of the site, for the links in the e-mail).
  """
  def deliver_to_owner(%Message{} = message, to, context) do
    new()
    |> to(to)
    |> from(sender())
    |> reply_to(reply_address(message))
    |> subject("[QuickSlips] #{Topic.name(message.topic)}: #{preview(message.message)}")
    |> text_body(owner_body(message, context))
    |> send_email()
  end

  @doc """
  Tells the sender that the message arrived. `owner` is the address of the owner, for the Reply-To. `context` has
  the `:locale` of the page (the language of the e-mail) and the `:site_url`.
  """
  def deliver_confirmation(%Message{} = message, owner, context) do
    Gettext.with_locale(QuickSlipsWeb.Gettext, context.locale.language, fn ->
      new()
      |> to(message.email)
      |> from(sender())
      |> reply_to(owner)
      |> subject(
        gettext("Your message to QuickSlips (%{reference})", reference: message.reference)
      )
      |> text_body(confirmation_body(message, context))
      |> send_email()
    end)
  end

  defp sender, do: {"QuickSlips", Application.fetch_env!(:quickslips, :mail_from)}

  defp send_email(email) do
    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  ## To the owner

  # The subject starts the message, on one line, so that the inbox says what each one is about.
  defp preview(text) do
    line = text |> String.replace(~r/[\p{C}\s]+/u, " ") |> String.trim()

    case String.split_at(line, 60) do
      {short, ""} -> short
      {short, rest} -> cut_at_word(short, rest) <> "…"
    end
  end

  # A cut in the middle of a word drops that word, unless there is no other to keep: text in Chinese or Japanese has
  # no spaces, and its 60 characters stay.
  defp cut_at_word(short, rest) do
    if String.starts_with?(rest, " ") or not String.contains?(short, " ") do
      String.trim_trailing(short)
    else
      short |> String.split(" ") |> Enum.drop(-1) |> Enum.join(" ")
    end
  end

  # With a name the owner sees "Asha Rao"; the characters that would end the quoted name early are left out of it.
  defp reply_address(%Message{name: nil, email: email}), do: email

  defp reply_address(%Message{name: name, email: email}) do
    case name
         |> String.replace(~r/[\p{C}"\\<>]/u, "")
         |> String.replace(~r/\s+/u, " ")
         |> String.trim() do
      "" -> email
      clean -> {clean, email}
    end
  end

  defp owner_body(%Message{} = message, context) do
    site_url = context[:site_url]

    [
      "A message from the contact form of QuickSlips.",
      "",
      line("Reference", message.reference),
      line("Topic", Topic.name(message.topic)),
      line("From", from_line(message)),
      context[:user] && line("Account", account(context.user)),
      message.locale && line("Language", message.locale),
      message.page && line("Page", (site_url || "") <> message.page),
      line("Sent", time(message.inserted_at)),
      site_url && message.id && line("Open", "#{site_url}/admin/messages/#{message.id}"),
      "",
      String.duplicate("-", 40),
      message.message,
      String.duplicate("-", 40),
      "",
      "Reply to this e-mail to answer the sender."
    ]
    |> Enum.filter(& &1)
    |> Enum.join("\n")
  end

  defp line(label, value), do: String.pad_trailing(label <> ":", 11) <> value

  defp from_line(%Message{name: nil, email: email}), do: email
  defp from_line(%Message{name: name, email: email}), do: "#{name} <#{email}>"

  defp account(user), do: "#{user.email} (user #{user.id})"

  ## To the sender

  defp confirmation_body(%Message{} = message, context) do
    [
      greeting(message),
      "",
      gettext(
        "Thank you for writing to QuickSlips. We have received your message and we will read it."
      ),
      "",
      gettext("Reference: %{reference}", reference: message.reference),
      gettext("Topic: %{topic}", topic: Topic.label(message.topic)),
      gettext("Received: %{time}", time: time(message.inserted_at)),
      "",
      gettext("Your message:"),
      String.duplicate("-", 40),
      message.message,
      String.duplicate("-", 40),
      "",
      gettext(
        "If we reply, it will be to this e-mail address. Please quote the reference if you write to us again."
      ),
      "",
      gettext("If you did not send this message, please ignore this e-mail."),
      "",
      case context[:site_url] do
        nil -> "QuickSlips"
        site_url -> "QuickSlips · #{site_url}"
      end
    ]
    |> Enum.join("\n")
  end

  defp greeting(%Message{name: nil}), do: gettext("Hello,")
  defp greeting(%Message{name: name}), do: gettext("Hello %{name},", name: name)

  defp time(%DateTime{} = time), do: Calendar.strftime(time, "%Y-%m-%d %H:%M UTC")
end
