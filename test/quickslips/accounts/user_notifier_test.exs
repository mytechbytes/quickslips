defmodule QuickSlips.Accounts.UserNotifierTest do
  # Changes the application environment, which every test shares.
  use ExUnit.Case, async: false

  import QuickSlips.SiteHelpers

  alias QuickSlips.Accounts.{User, UserNotifier, UserToken}
  alias QuickSlips.Locales
  alias QuickSlips.Mail.Letter

  # The e-mails about an account (confirm it, log in with a link, change its address): who they come from, what
  # they say, that they are in the language the person chose, and what is in them to make the person act.

  @url "http://localhost/link"

  setup do
    previous = Application.fetch_env!(:quickslips, :mail_from)
    Application.put_env(:quickslips, :mail_from, "no-reply@mail.example.test")
    on_exit(fn -> Application.put_env(:quickslips, :mail_from, previous) end)
    put_contact_email(nil)
  end

  defp confirmed_user,
    do: %User{
      email: "person@example.test",
      hashed_password: "hash",
      confirmed_at: ~U[2026-01-01 00:00:00Z]
    }

  defp new_user,
    do: %User{email: "person@example.test", hashed_password: "hash", confirmed_at: nil}

  defp locale(code), do: Locales.fetch!(code)

  test "emails come from the configured address" do
    user = %User{email: "person@example.test", confirmed_at: ~U[2026-01-01 00:00:00Z]}

    assert {:ok, email} = UserNotifier.deliver_login_instructions(user, "http://localhost/link")
    assert email.from == {"QuickSlips", "no-reply@mail.example.test"}
    assert email.to == [{"", "person@example.test"}]
  end

  describe "deliver_login_instructions/3" do
    test "logs in with a link when the account is confirmed" do
      assert {:ok, email} = UserNotifier.deliver_login_instructions(confirmed_user(), @url)

      assert email.subject == "Your QuickSlips log-in link"
      assert email.html_body =~ ~s(href="#{@url}")
      assert email.text_body =~ @url
      assert email.text_body =~ "Log in\n#{@url}"
    end

    test "confirms the account instead when it was never confirmed" do
      assert {:ok, email} = UserNotifier.deliver_login_instructions(new_user(), @url)

      assert email.subject == "Confirm your QuickSlips account"
      assert email.html_body =~ ~s(href="#{@url}")
      assert email.text_body =~ "Confirm my account\n#{@url}"
    end

    test "is written in the language of the locale it is given" do
      assert {:ok, email} =
               UserNotifier.deliver_login_instructions(confirmed_user(), @url,
                 locale: locale("hi-in")
               )

      assert email.subject == "आपका QuickSlips लॉग इन लिंक"
      assert email.html_body =~ ~s(<html lang="hi")
      assert email.text_body =~ "लॉग इन"
      refute email.text_body =~ "Log in"
    end

    test "is in English when it is given no locale" do
      assert {:ok, email} = UserNotifier.deliver_login_instructions(confirmed_user(), @url, [])

      assert email.html_body =~ ~s(<html lang="en")
    end
  end

  describe "deliver_update_email_instructions/3" do
    test "goes to the new address and asks to confirm it" do
      user = %User{email: "new@example.test"}

      assert {:ok, email} = UserNotifier.deliver_update_email_instructions(user, @url)

      assert email.to == [{"", "new@example.test"}]
      assert email.subject == "Confirm your new QuickSlips email address"
      assert email.html_body =~ ~s(href="#{@url}")
      assert email.text_body =~ "Confirm new email address\n#{@url}"
    end

    test "is written in the language of the locale it is given" do
      user = %User{email: "new@example.test"}

      assert {:ok, email} =
               UserNotifier.deliver_update_email_instructions(user, @url, locale: locale("es-es"))

      assert email.subject == "Confirma tu nuevo correo electrónico de QuickSlips"
      assert email.html_body =~ ~s(<html lang="es")
    end
  end

  describe "what the letters say" do
    test "how long the link works, from the lifetime of the token itself" do
      minutes = UserToken.magic_link_validity_in_minutes()
      days = UserToken.change_email_validity_in_days()

      assert note(UserNotifier.confirmation_letter(new_user(), @url)) =~ "for #{minutes} minutes"
      assert note(UserNotifier.login_letter(confirmed_user(), @url)) =~ "for #{minutes} minutes"
      assert note(UserNotifier.update_email_letter(confirmed_user(), @url)) =~ "for #{days} days"
    end

    test "that the e-mail can be ignored by whoever did not ask for it" do
      assert note(UserNotifier.confirmation_letter(new_user(), @url)) =~ "ignore this email"
      assert note(UserNotifier.login_letter(confirmed_user(), @url)) =~ "ignore this email"
      assert note(UserNotifier.update_email_letter(confirmed_user(), @url)) =~ "ignore this email"
    end

    test "to whom it was sent and why, in the foot" do
      for letter <- [
            UserNotifier.confirmation_letter(new_user(), @url),
            UserNotifier.login_letter(confirmed_user(), @url),
            UserNotifier.update_email_letter(confirmed_user(), @url)
          ] do
        assert [reason] = letter.footer
        assert reason =~ "person@example.test"
      end
    end

    test "the confirmation asks for the password only of an account that has one" do
      with_password = UserNotifier.confirmation_letter(new_user(), @url)
      without = UserNotifier.confirmation_letter(%{new_user() | hashed_password: nil}, @url)

      assert {:text, "When the page asks, enter the password you chose at sign-up."} in with_password.blocks

      refute {:text, "When the page asks, enter the password you chose at sign-up."} in without.blocks
    end

    test "the confirmation has a way forward: three of the most used bills, in the language of the person" do
      assert {:links, heading, links} =
               links_block(UserNotifier.confirmation_letter(new_user(), @url))

      assert heading == "Make your first bill"
      assert length(links) == 3
      assert Enum.all?(links, fn {_label, url} -> url =~ ~r{^http://localhost:\d+/en-in/} end)

      assert {:links, "अपना पहला बिल बनाएं", hindi} =
               links_block(UserNotifier.confirmation_letter(new_user(), @url, locale("hi-in")))

      assert length(hindi) == 3
      assert Enum.all?(hindi, fn {_label, url} -> url =~ ~r{^http://localhost:\d+/hi-in/} end)
    end

    test "only the confirmation has it: a log-in link or a new address is not the place for a suggestion" do
      assert links_block(UserNotifier.login_letter(confirmed_user(), @url)) == nil
      assert links_block(UserNotifier.update_email_letter(confirmed_user(), @url)) == nil
    end

    test "one button each, and it is the link" do
      for letter <- [
            UserNotifier.confirmation_letter(new_user(), @url),
            UserNotifier.login_letter(confirmed_user(), @url),
            UserNotifier.update_email_letter(confirmed_user(), @url)
          ] do
        assert [{:button, _label, @url}] =
                 Enum.filter(letter.blocks, &match?({:button, _, _}, &1))
      end
    end
  end

  describe "a reply" do
    test "has nowhere to go when the site has no contact address" do
      assert {:ok, email} = UserNotifier.deliver_login_instructions(confirmed_user(), @url)

      assert email.reply_to == nil
      refute email.text_body =~ "Questions?"
    end

    test "goes to the contact address, and the foot says that somebody reads it, when there is one" do
      put_contact_email("owner@example.org")

      assert {:ok, email} = UserNotifier.deliver_login_instructions(confirmed_user(), @url)

      assert email.reply_to == {"", "owner@example.org"}
      assert email.text_body =~ "Questions? Reply to this email and a person will read it."
      assert email.html_body =~ "Questions? Reply to this email and a person will read it."
    end
  end

  describe "the languages of the site" do
    # A message with no translation is shown in English, so a language that is missing one would send an e-mail that
    # is half in English. Every sentence of every letter is compared with the English one.
    test "every letter is written in each of them, with no sentence left in English" do
      english = letters(locale("en-in"))

      for locale <- Locales.live(), locale.language != "en", {kind, letter} <- letters(locale) do
        assert letter.language == locale.language
        english_texts = texts(Map.fetch!(english, kind))
        own_texts = texts(letter)
        assert length(own_texts) == length(english_texts), "#{locale.code} #{kind}: another shape"

        for {text, in_english} <- Enum.zip(own_texts, english_texts) do
          refute text == in_english,
                 "#{locale.code} #{kind}: #{inspect(in_english)} is not translated"

          refute text =~ "%{", "#{locale.code} #{kind}: a placeholder is left in #{inspect(text)}"
        end
      end
    end

    test "every e-mail says its language in the HTML, and has its own address and link in both versions" do
      for locale <- Locales.live(), user <- [new_user(), confirmed_user()] do
        assert {:ok, email} = UserNotifier.deliver_login_instructions(user, @url, locale: locale)

        assert email.html_body =~ ~s(<html lang="#{locale.language}")
        assert email.html_body =~ "person@example.test"
        assert email.text_body =~ "person@example.test"
        assert email.html_body =~ ~s(href="#{@url}")
        assert email.text_body =~ @url
      end
    end
  end

  defp letters(locale) do
    %{
      confirm: UserNotifier.confirmation_letter(new_user(), @url, locale),
      login: UserNotifier.login_letter(confirmed_user(), @url, locale),
      change: UserNotifier.update_email_letter(confirmed_user(), @url, locale)
    }
  end

  # Every sentence of a letter, in order. The addresses and the links are the same in every language, so they are not
  # in the list.
  defp texts(%Letter{} = letter) do
    [letter.subject, letter.preheader, letter.heading] ++
      Enum.flat_map(letter.blocks, &block_texts/1) ++ letter.footer
  end

  defp block_texts({:text, text}), do: [text]
  defp block_texts({:note, text}), do: [text]
  defp block_texts({:button, label, _url}), do: [label]
  defp block_texts({:links, heading, _links}), do: [heading]

  defp note(%Letter{blocks: blocks}) do
    Enum.find_value(blocks, fn
      {:note, text} -> text
      _other -> nil
    end)
  end

  defp links_block(%Letter{blocks: blocks}), do: Enum.find(blocks, &match?({:links, _, _}, &1))
end
