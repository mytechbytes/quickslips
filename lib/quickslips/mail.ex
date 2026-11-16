defmodule QuickSlips.Mail do
  @moduledoc """
  Sends the e-mails of the site: the one place that makes a `Swoosh.Email` from a `QuickSlips.Mail.Letter`.

  Every e-mail of QuickSlips goes through `deliver/3`, so that they all look and behave alike:

    * the same sender, `"QuickSlips" <MAIL_FROM>`;
    * an HTML version (`QuickSlips.Mail.Layout`: the logo, the colours, one clear button) and a plain-text version
      (`QuickSlips.Mail.Text`) of the same letter, which is what mail providers expect of a real message;
    * a `Reply-To` when there is somebody who reads the answers;
    * the headers `Auto-Submitted` and `X-Auto-Response-Suppress`, which say that a program wrote the e-mail, so that
      out-of-office robots do not answer it;
    * a `Message-ID` on the domain of the sender and a `Date` in UTC, written here because the mail library's own are
      made from the name and the time zone of the server;
    * nothing that is only for advertising: no `List-Unsubscribe`, no tracking pixel, no tracked links. The e-mails
      carry what the person asked for (a link to log in, a confirmation), and the privacy page says so.

  The language of the e-mail is the one of the letter (`letter.language`): the words around the letter (the tagline,
  the links of the foot) are written in it here.
  """
  use Gettext, backend: QuickSlipsWeb.Gettext

  alias QuickSlips.Mail.{Layout, Letter, Text}
  alias QuickSlips.{Mailer, Site}
  alias Swoosh.Email

  @doc """
  Makes the e-mail of `letter` for `to` and sends it. Returns `{:ok, email}`, or the error of the mail provider.

  Options:

    * `:reply_to` - the address (or `{name, address}`) that an answer goes to; none by default;
    * `:invite_reply?` - say in the foot that a reply is read (only when there is a `:reply_to` that somebody reads);
    * `:site_url` - the address of the site, for the logo and the links of the foot; the address of the endpoint by
      default.
  """
  def deliver(%Letter{} = letter, to, opts \\ []) do
    %{html: html, text: text} = render(letter, opts)

    email =
      Email.new()
      |> Email.to(to)
      |> Email.from(sender())
      |> reply_to(opts[:reply_to])
      |> Email.subject(letter.subject)
      |> Email.text_body(text)
      |> Email.html_body(html)
      |> Email.header("Auto-Submitted", "auto-generated")
      |> Email.header("X-Auto-Response-Suppress", "OOF, AutoReply")
      |> Email.header("Message-ID", message_id())
      |> Email.header("Date", date())

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end

  # The mail library makes a Message-ID from the name of the server, which in a container is a string of random
  # letters with no domain, and spam filters look for exactly that. This one is on the domain of the sender and never
  # repeats.
  defp message_id do
    {_name, address} = sender()
    domain = address |> String.split("@") |> List.last() |> String.trim_trailing(">")

    "<" <> Base.encode16(:crypto.strong_rand_bytes(16), case: :lower) <> "@" <> domain <> ">"
  end

  # The mail library writes the Date in the time zone of the server, and gets half-hour zones wrong (India shows as
  # +0550). In UTC there is nothing to get wrong.
  defp date, do: Calendar.strftime(DateTime.utc_now(), "%a, %d %b %Y %H:%M:%S +0000")

  @doc """
  The two versions of `letter` without sending anything: `%{html: "...", text: "..."}`. The options are the ones of
  `deliver/3` that change what is printed (`:invite_reply?`, `:site_url`). The preview (`mix quickslips.mail.preview`)
  and the tests use it.
  """
  def render(%Letter{} = letter, opts \\ []) do
    site_url = opts[:site_url] || QuickSlipsWeb.Endpoint.url()
    frame = frame(letter.language, site_url, opts)

    %{html: Layout.render(letter, frame), text: Text.render(letter, frame)}
  end

  @doc "The sender of every e-mail: the name of the site and the address of `MAIL_FROM`."
  def sender, do: {"QuickSlips", Application.fetch_env!(:quickslips, :mail_from)}

  defp reply_to(email, nil), do: email
  defp reply_to(email, address), do: Email.reply_to(email, address)

  # What goes around every letter, in the language of the letter. The site address is the base of the logo and of the
  # links; "Contact" is only offered when the site has an address to be contacted at (as in the footer of the site).
  defp frame(language, site_url, opts) do
    Gettext.with_locale(QuickSlipsWeb.Gettext, language, fn ->
      %{
        site_url: site_url,
        logo_url: site_url <> "/images/email/logo.png",
        tagline: gettext("Bills and receipts, ready in seconds"),
        link_hint: gettext("Or copy and paste this link into your browser:"),
        reply_line:
          if(opts[:invite_reply?],
            do: gettext("Questions? Reply to this email and a person will read it.")
          ),
        links:
          if(Site.contact_email(), do: [{gettext("Contact"), site_url <> "/contact"}], else: []) ++
            [
              {gettext("Privacy"), site_url <> "/privacy"},
              {gettext("Terms"), site_url <> "/terms"}
            ]
      }
    end)
  end
end
