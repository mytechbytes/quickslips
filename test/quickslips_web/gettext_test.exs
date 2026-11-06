defmodule QuickSlipsWeb.GettextTest do
  use ExUnit.Case, async: true

  # Every text of the site is in Hindi and in Spanish. A missing translation would show up in English on a Hindi
  # page, so this test fails until it is written. After adding a `gettext("...")` run `mix gettext.extract --merge`,
  # then fill in `msgstr` in `priv/gettext/hi` and `priv/gettext/es`.

  defp texts(%Expo.Message.Singular{msgstr: msgstr}), do: [IO.iodata_to_binary(msgstr)]

  defp texts(%Expo.Message.Plural{msgstr: forms}),
    do: forms |> Map.values() |> Enum.map(&IO.iodata_to_binary/1)

  defp msgid(message), do: IO.iodata_to_binary(message.msgid)

  # `%{name}` in a text. A translation may leave one out, but one that the program does not give raises at run time.
  defp placeholders(text),
    do: ~r/%\{(\w+)\}/ |> Regex.scan(text) |> Enum.map(&List.last/1) |> Enum.uniq()

  for language <- ["hi", "es"], domain <- ["default", "errors"] do
    describe "priv/gettext/#{language}/LC_MESSAGES/#{domain}.po" do
      setup do
        %{
          po:
            Expo.PO.parse_file!(
              "priv/gettext/#{unquote(language)}/LC_MESSAGES/#{unquote(domain)}.po"
            ),
          pot: Expo.PO.parse_file!("priv/gettext/#{unquote(domain)}.pot")
        }
      end

      test "has the messages of the template, no more and no fewer", %{po: po, pot: pot} do
        ids = fn file -> file.messages |> Enum.map(&msgid/1) |> Enum.sort() end

        assert ids.(po) == ids.(pot), "run `mix gettext.extract --merge`"
      end

      test "translates every message, in every plural form", %{po: po} do
        for message <- po.messages, text <- texts(message) do
          assert text != "", "#{unquote(language)}: #{inspect(msgid(message))} is not translated"
        end
      end

      test "has no message that is marked as a guess", %{po: po} do
        for message <- po.messages do
          refute "fuzzy" in List.flatten(message.flags),
                 "#{unquote(language)}: #{inspect(msgid(message))} is a guess (fuzzy)"
        end
      end

      test "uses only the placeholders of its message", %{po: po} do
        for message <- po.messages, text <- texts(message) do
          # a plural message is also given `%{count}`
          allowed = ["count" | placeholders(msgid(message))]

          assert placeholders(text) -- allowed == [],
                 "#{unquote(language)}: #{inspect(text)} has a placeholder that #{inspect(msgid(message))} has not"
        end
      end

      test "says how many plural forms it has", %{po: po} do
        assert Enum.any?(po.headers, &String.starts_with?(&1, "Plural-Forms: nplurals=2;"))
      end
    end
  end
end
