defmodule QuickSlips.Accounts.UserNotifier do
  @moduledoc """
  The e-mails about an account: confirming it, logging in with a link, and changing its address.

  Each one is described as a `QuickSlips.Mail.Letter` in the language the person chose on the site, and sent by
  `QuickSlips.Mail`, which gives all the e-mails of the site the same look, the same sender and the same headers. The
  language comes in as the `:locale` option (one of `QuickSlips.Locales`; the default locale when there is none), so
  it is the one of the page where the person asked for the e-mail, not a guess.

  The functions that end in `_letter` only build the letter, in the language of the locale, and send nothing. The
  preview (`mix quickslips.mail.preview`) and the tests use them to see an e-mail.

  When the site has a contact address (`CONTACT_EMAIL`), an answer to these e-mails goes to it, and the foot of the
  e-mail says that somebody reads the answers. Without one, the e-mails have no Reply-To.
  """
  use Gettext, backend: QuickSlipsWeb.Gettext

  alias QuickSlips.Accounts.{User, UserToken}
  alias QuickSlips.{Locales, Mail, Site}
  alias QuickSlips.Mail.Letter
  alias QuickSlipsWeb.Footer

  @doc """
  Deliver instructions to update a user email: `user` has the new address, which is where the e-mail goes.
  """
  def deliver_update_email_instructions(%User{} = user, url, opts \\ []) do
    deliver(update_email_letter(user, url, locale(opts)), user)
  end

  @doc """
  Deliver instructions to log in with a magic link. An account that was never confirmed gets the e-mail that
  confirms it instead.
  """
  def deliver_login_instructions(%User{} = user, url, opts \\ []) do
    case user do
      %User{confirmed_at: nil} -> deliver(confirmation_letter(user, url, locale(opts)), user)
      _ -> deliver(login_letter(user, url, locale(opts)), user)
    end
  end

  defp locale(opts), do: Keyword.get(opts, :locale) || Locales.default()

  defp deliver(%Letter{} = letter, %User{} = user) do
    contact = Site.contact_email()
    Mail.deliver(letter, user.email, reply_to: contact, invite_reply?: contact != nil)
  end

  ## The letters

  @doc "The e-mail that confirms a new account, in the language of `locale`."
  def confirmation_letter(%User{} = user, url, locale \\ Locales.default()) do
    in_language(locale, fn ->
      %Letter{
        language: locale.language,
        subject: gettext("Confirm your QuickSlips account"),
        preheader: gettext("One step left: confirm your email address."),
        heading: gettext("Confirm your email address"),
        blocks:
          [
            {:text, gettext("Hello,")},
            {:text,
             gettext(
               "Welcome to QuickSlips. Confirm your email address to finish creating your account."
             )}
          ] ++
            password_hint(user) ++
            [
              {:button, gettext("Confirm my account"), url},
              {:note,
               gettext(
                 "The link works once and for %{minutes} minutes. If you didn't create a QuickSlips account, ignore this email and nothing will happen.",
                 minutes: UserToken.magic_link_validity_in_minutes()
               )}
            ] ++ first_bills(locale),
        footer: [
          gettext(
            "You are receiving this email because %{email} was used to create a QuickSlips account.",
            email: user.email
          )
        ]
      }
    end)
  end

  @doc "The e-mail with the link that logs in, in the language of `locale`."
  def login_letter(%User{} = user, url, locale \\ Locales.default()) do
    in_language(locale, fn ->
      minutes = UserToken.magic_link_validity_in_minutes()

      %Letter{
        language: locale.language,
        subject: gettext("Your QuickSlips log-in link"),
        preheader:
          gettext("Use this link to log in. It works once, for %{minutes} minutes.",
            minutes: minutes
          ),
        heading: gettext("Log in to QuickSlips"),
        blocks: [
          {:text, gettext("Hello,")},
          {:text,
           gettext(
             "Use the button below to log in to your account. You don't need your password."
           )},
          {:button, gettext("Log in"), url},
          {:note,
           gettext(
             "The link works once and for %{minutes} minutes. If you didn't ask for it, ignore this email: nobody can log in without it.",
             minutes: minutes
           )}
        ],
        footer: [
          gettext(
            "You are receiving this email because someone asked for a log-in link for %{email} on QuickSlips.",
            email: user.email
          )
        ]
      }
    end)
  end

  @doc "The e-mail that confirms a new address for an account, in the language of `locale`."
  def update_email_letter(%User{} = user, url, locale \\ Locales.default()) do
    in_language(locale, fn ->
      %Letter{
        language: locale.language,
        subject: gettext("Confirm your new QuickSlips email address"),
        preheader: gettext("Confirm this address to use it for your QuickSlips account."),
        heading: gettext("Confirm your new email address"),
        blocks: [
          {:text, gettext("Hello,")},
          {:text,
           gettext(
             "You asked to change the email address of your QuickSlips account to this one. Confirm the change with the button below."
           )},
          {:button, gettext("Confirm new email address"), url},
          {:note,
           gettext(
             "The link works once and for %{days} days. If you didn't ask for this change, ignore this email and your account stays as it is.",
             days: UserToken.change_email_validity_in_days()
           )}
        ],
        footer: [
          gettext(
            "You are receiving this email because %{email} was entered as the new address of a QuickSlips account.",
            email: user.email
          )
        ]
      }
    end)
  end

  defp in_language(locale, build) do
    Gettext.with_locale(QuickSlipsWeb.Gettext, locale.language, build)
  end

  # Whoever signed up with a password is asked for it on the page that the link opens; an account without one is not.
  defp password_hint(%User{hashed_password: nil}), do: []

  defp password_hint(%User{}),
    do: [{:text, gettext("When the page asks, enter the password you chose at sign-up.")}]

  # A way forward for the person who has just joined: three of the most used bills, in their language and at their
  # country's pages (the same ones as the foot of the site). A language that has none of them gets no block.
  defp first_bills(locale) do
    site_url = QuickSlipsWeb.Endpoint.url()

    case locale |> Footer.popular() |> Enum.take(3) do
      [] ->
        []

      bills ->
        [
          {:links, gettext("Make your first bill"),
           for(%{label: label, to: path} <- bills, do: {label, site_url <> path})}
        ]
    end
  end
end
