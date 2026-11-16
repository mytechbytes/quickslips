defmodule QuickSlips.Contact.Notifier do
  @moduledoc """
  The two e-mails that a message from the contact form causes.

  *To the owner* (`deliver_to_owner/3`): it comes from the site's own address (`MAIL_FROM`, which the mail provider
  has agreed to send for) and has the sender's address as Reply-To, so answering it from the mailbox answers the
  visitor. The owner reads it, so it is in English whatever the language of the page was; it says which language
  and country the visitor was on.

  *To the sender* (`deliver_confirmation/3`): in the language the visitor chose, to greet them by name, say that the
  message arrived, what its reference is, and to give their words back. The address may be somebody else's, so this
  is limited (Turnstile for everybody, and a few confirmations a day to one address); the e-mail says to ignore it
  if it was not sent by them. Its Reply-To is the owner's, so an answer to it is read.

  Both are described as a `QuickSlips.Mail.Letter` and sent by `QuickSlips.Mail`, like every e-mail of the site. The
  words of the visitor are shown as text (never as links) in a box of their own, whoever reads them.
  `owner_letter/2` and `confirmation_letter/2` only build the letter, for the preview and the tests.
  """
  use Gettext, backend: QuickSlipsWeb.Gettext

  alias QuickSlips.Contact.{Message, Topic}
  alias QuickSlips.Mail
  alias QuickSlips.Mail.Letter

  @doc """
  Sends `message` to `to`, the owner. `context` says what the form knew besides the message: `:user` (who was logged
  in, or nothing) and `:site_url` (the address of the site, for the links in the e-mail).
  """
  def deliver_to_owner(%Message{} = message, to, context) do
    Mail.deliver(owner_letter(message, context), to,
      reply_to: reply_address(message),
      site_url: context[:site_url]
    )
  end

  @doc """
  Tells the sender that the message arrived. `owner` is the address of the owner, for the Reply-To. `context` has
  the `:locale` of the page (the language of the e-mail) and the `:site_url`.
  """
  def deliver_confirmation(%Message{} = message, owner, context) do
    Mail.deliver(confirmation_letter(message, context), message.email,
      reply_to: owner,
      site_url: context[:site_url]
    )
  end

  ## To the owner

  @doc "The e-mail to the owner, in English."
  def owner_letter(%Message{} = message, context) do
    site_url = context[:site_url]

    rows =
      Enum.filter(
        [
          {"Reference", message.reference},
          {"Topic", Topic.name(message.topic)},
          {"From", from_line(message)},
          context[:user] && {"Account", account(context.user)},
          message.locale && {"Language", message.locale},
          message.page && {"Page", address(site_url, message.page)},
          {"Sent", time(message.inserted_at)},
          site_url && message.id &&
            {"Open", {:link, "#{site_url}/admin/messages/#{message.id}"}}
        ],
        & &1
      )

    %Letter{
      language: "en",
      subject: "[QuickSlips] #{Topic.name(message.topic)}: #{preview(message.message)}",
      preheader: "From #{from_line(message)}",
      heading: "New message from the contact form",
      blocks: [
        {:facts, rows},
        {:quote, nil, message.message},
        {:text, "Reply to this e-mail to answer the sender."}
      ],
      footer: [
        "You are receiving this e-mail because your address is where the contact form of QuickSlips sends its messages."
      ]
    }
  end

  # A page of the site is a link when the site's address is known, and its path alone when it is not.
  defp address(nil, path), do: path
  defp address(site_url, path), do: {:link, site_url <> path}

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

  defp from_line(%Message{name: nil, email: email}), do: email
  defp from_line(%Message{name: name, email: email}), do: "#{name} <#{email}>"

  defp account(user), do: "#{user.email} (user #{user.id})"

  ## To the sender

  @doc "The confirmation to the sender, in the language of `context.locale`."
  def confirmation_letter(%Message{} = message, context) do
    locale = context.locale

    Gettext.with_locale(QuickSlipsWeb.Gettext, locale.language, fn ->
      %Letter{
        language: locale.language,
        subject:
          gettext("Your message to QuickSlips (%{reference})", reference: message.reference),
        preheader: gettext("Your reference is %{reference}.", reference: message.reference),
        heading: gettext("We have your message"),
        blocks: [
          {:text, greeting(message)},
          {:text,
           gettext(
             "Thank you for writing to QuickSlips. We have received your message and we will read it."
           )},
          {:lines,
           [
             gettext("Reference: %{reference}", reference: message.reference),
             gettext("Topic: %{topic}", topic: Topic.label(message.topic)),
             gettext("Received: %{time}", time: time(message.inserted_at))
           ]},
          {:quote, gettext("Your message:"), message.message},
          {:text,
           gettext(
             "If we reply, it will be to this e-mail address. Please quote the reference if you write to us again."
           )},
          {:note, gettext("If you did not send this message, please ignore this e-mail.")}
        ],
        footer: [
          gettext(
            "You are receiving this email because %{email} was entered in the contact form on QuickSlips.",
            email: message.email
          )
        ]
      }
    end)
  end

  defp greeting(%Message{name: nil}), do: gettext("Hello,")
  defp greeting(%Message{name: name}), do: gettext("Hello %{name},", name: name)

  defp time(%DateTime{} = time), do: Calendar.strftime(time, "%Y-%m-%d %H:%M UTC")
end
