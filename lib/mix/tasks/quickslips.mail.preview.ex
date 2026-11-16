defmodule Mix.Tasks.Quickslips.Mail.Preview do
  @shortdoc "Writes every e-mail of the site, in every language, to tmp/mail-preview"

  @moduledoc """
  Writes the e-mails of the site as files that a browser can open, to look at them and to read their translations
  without sending anything:

      mix quickslips.mail.preview

  It makes `tmp/mail-preview/index.html`, which links to every e-mail (confirm an account, log in, change the
  address, the two contact e-mails) in every language of the site, as HTML and as plain text. The text of each one
  is the real text of the application, with an example address, an example link and an example message. The files
  hold everything they show (the logo too), so open the index in a browser as it is, with no server. Switch the
  computer to dark mode, or make the window narrow, to see the other looks of the same e-mail.

  The application is started for it (it needs the list of bills for the "make your first bill" links), so
  the database of the development environment has to be running, as for `mix phx.server`.
  """
  use Mix.Task

  alias QuickSlips.Accounts.{User, UserNotifier}
  alias QuickSlips.Contact.{Message, Notifier}
  alias QuickSlips.{Locales, Mail}

  @requirements ["app.start"]

  # The e-mails that depend on the language of the visitor, in the order of the index: `{file name, title}`.
  @kinds [
    {"confirm-account", "Confirm an account"},
    {"log-in", "Log in with a link"},
    {"new-address", "Confirm a new address"},
    {"contact-confirmation", "Contact form: to the sender"}
  ]

  @impl Mix.Task
  def run(_args) do
    out = Path.join(File.cwd!(), "tmp/mail-preview")
    File.rm_rf!(out)
    File.mkdir_p!(out)

    logo =
      [:code.priv_dir(:quickslips), "static/images/email/logo.png"]
      |> Path.join()
      |> File.read!()
      |> Base.encode64()

    site = QuickSlipsWeb.Endpoint.url()
    locales = Locales.live()

    for locale <- locales, {kind, _title} <- @kinds do
      write(out, "#{kind}-#{locale.code}", letter(kind, locale, site), site, logo)
    end

    owner = Notifier.owner_letter(message(), context(hd(locales), site))
    write(out, "contact-owner", owner, site, logo)
    File.write!(Path.join(out, "index.html"), index(locales))

    Mix.shell().info("Wrote #{length(locales) * length(@kinds) + 1} e-mails to #{out}/index.html")
  end

  defp letter("confirm-account", locale, site),
    do: UserNotifier.confirmation_letter(user(), site <> "/users/log-in/EXAMPLE-LINK", locale)

  defp letter("log-in", locale, site),
    do: UserNotifier.login_letter(user(), site <> "/users/log-in/EXAMPLE-LINK", locale)

  defp letter("new-address", locale, site),
    do:
      UserNotifier.update_email_letter(
        user(),
        site <> "/users/settings/confirm-email/EXAMPLE-LINK",
        locale
      )

  defp letter("contact-confirmation", locale, site),
    do: Notifier.confirmation_letter(message(), context(locale, site))

  defp user, do: %User{id: 1, email: "asha@example.com", hashed_password: "example"}

  defp message do
    %Message{
      id: 1,
      reference: "ABCD-2345",
      topic: :problem,
      name: "Asha Rao",
      email: "asha@example.com",
      message: "The fuel bill has no line for GST.\n\nCould you add one?",
      locale: "en-IN",
      page: "/en-in/fuel-bill-generator",
      inserted_at: ~U[2026-11-16 12:00:00Z]
    }
  end

  defp context(locale, site), do: %{user: nil, locale: locale, page: nil, site_url: site}

  # The logo of an e-mail is a picture on the address of the site. In the preview it is put into the file itself, so
  # that the file shows it wherever it is opened, without the site running.
  defp write(out, name, letter, site, logo) do
    %{html: html, text: text} = Mail.render(letter, invite_reply?: true, site_url: site)

    File.write!(
      Path.join(out, name <> ".html"),
      String.replace(html, site <> "/images/email/logo.png", "data:image/png;base64," <> logo)
    )

    File.write!(Path.join(out, name <> ".txt"), text)
  end

  defp index(locales) do
    head =
      for {_kind, title} <- @kinds, into: "<th>Language</th>", do: "<th>#{title}</th>"

    rows =
      for locale <- locales do
        cells =
          for {kind, _title} <- @kinds, into: "" do
            name = "#{kind}-#{locale.code}"
            ~s(<td><a href="#{name}.html">HTML</a> · <a href="#{name}.txt">text</a></td>)
          end

        "<tr><th>#{locale.name} (#{locale.code})</th>#{cells}</tr>"
      end

    """
    <!doctype html>
    <html lang="en"><head><meta charset="utf-8"><title>E-mail preview</title>
    <style>
    body { font: 16px/1.5 system-ui, sans-serif; margin: 2rem; color: #161c19; background: #faf7f0; }
    table { border-collapse: collapse; } th, td { padding: .5rem 1rem; border: 1px solid #e4e1d8; text-align: left; }
    a { color: #187a60; }
    </style></head><body>
    <h1>E-mail preview</h1>
    <p>Made by <code>mix quickslips.mail.preview</code>. The e-mail to the owner is in English only:
    <a href="contact-owner.html">HTML</a> · <a href="contact-owner.txt">text</a>.</p>
    <table><tr>#{head}</tr>#{Enum.join(rows)}</table>
    </body></html>
    """
  end
end
