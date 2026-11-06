defmodule QuickSlipsWeb.ErrorMessagesTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Templates.Validator
  alias QuickSlipsWeb.ErrorMessages

  # A schema with a field of every type, and data that breaks every rule once.
  @schema %{
    "fields" => [
      %{"key" => "name", "type" => "text", "required" => true, "max_length" => 5},
      %{"key" => "note", "type" => "textarea", "max_length" => 3},
      %{"key" => "count", "type" => "number", "min" => 1, "max" => 10},
      %{"key" => "when", "type" => "date"},
      %{"key" => "month", "type" => "month"},
      %{"key" => "kind", "type" => "select", "options" => ["A", "B"]},
      %{"key" => "odd", "type" => "weird"}
    ]
  }

  defp errors(data) do
    {:error, {:validation, errors}} = Validator.validate(@schema, data)
    errors
  end

  @broken [
    %{},
    %{
      "name" => 5,
      "note" => 1,
      "count" => "x",
      "when" => "tomorrow",
      "month" => "2026-13",
      "kind" => "C",
      "odd" => "?"
    },
    %{"name" => "too long", "note" => "toolong", "count" => 0},
    %{"name" => "ok", "count" => 11}
  ]

  test "English stays English" do
    for data <- @broken do
      assert ErrorMessages.translate_validation(errors(data), "en") == errors(data)
    end
  end

  test "every message of the validator has a Hindi and a Spanish version" do
    for language <- ["hi", "es"], data <- @broken do
      english = errors(data)
      translated = ErrorMessages.translate_validation(english, language)

      assert Map.keys(translated) == Map.keys(english)

      for {field, messages} <- translated,
          {message, original} <- Enum.zip(messages, english[field]) do
        assert message != original, "#{language}: #{inspect(original)} was not translated"
        refute message =~ "%{", "#{language}: #{inspect(message)} has an unfilled placeholder"
      end
    end
  end

  test "the numbers of a message come along" do
    assert %{"name" => ["debe tener como máximo 5 caracteres"]} =
             ErrorMessages.translate_validation(
               %{"name" => ["must be at most 5 characters"]},
               "es"
             )

    assert %{"count" => ["अधिकतम 10 होना चाहिए"]} =
             ErrorMessages.translate_validation(%{"count" => ["must be at most 10"]}, "hi")

    assert %{"count" => ["debe ser como mínimo 0.01"]} =
             ErrorMessages.translate_validation(%{"count" => ["must be at least 0.01"]}, "es")

    assert %{"kind" => ["debe ser uno de: Petrol, Diesel, CNG"]} =
             ErrorMessages.translate_validation(
               %{"kind" => ["must be one of: Petrol, Diesel, CNG"]},
               "es"
             )
  end

  test "a message it does not know stays as it is, and a field keeps all its messages" do
    assert %{"a" => ["is required", "something new"]} =
             ErrorMessages.translate_validation(%{"a" => ["is required", "something new"]}, "xx")
  end

  test "does not change the language of the caller" do
    Gettext.put_locale(QuickSlipsWeb.Gettext, "hi")
    ErrorMessages.translate_validation(%{"a" => ["is required"]}, "es")

    assert Gettext.get_locale(QuickSlipsWeb.Gettext) == "hi"
  end
end
