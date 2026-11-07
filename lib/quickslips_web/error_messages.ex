defmodule QuickSlipsWeb.ErrorMessages do
  @moduledoc """
  The messages that the app writes itself, in the language of the visitor. They live in the `errors` domain of
  Gettext, next to the messages of Ecto.

  Two kinds:

    * what `QuickSlips.Templates.Validator` says about the data of a bill (`translate_validation/2`). It is plain
      English text, so a message that carries a number (`must be at most 80 characters`) is taken apart here;
    * what `QuickSlips.Accounts.User` says in its changesets. `CoreComponents.translate_error/1` looks those up at
      run time. Gettext can't see a message that is only a string in a changeset, so `changeset_messages/0` lists
      them for `mix gettext.extract`.
  """
  use Gettext, backend: QuickSlipsWeb.Gettext

  @doc """
  The errors of a validation (`%{"station_name" => ["is required"]}`) with every message in `language` (`"hi"`).
  A message that is not known stays as it is.
  """
  def translate_validation(errors, language) do
    Gettext.with_locale(QuickSlipsWeb.Gettext, language, fn ->
      Map.new(errors, fn {field, messages} -> {field, Enum.map(messages, &translate/1)} end)
    end)
  end

  defp translate("is required"), do: dgettext("errors", "is required")
  defp translate("must be text"), do: dgettext("errors", "must be text")
  defp translate("must be a number"), do: dgettext("errors", "must be a number")
  defp translate("must be an object"), do: dgettext("errors", "must be an object")
  defp translate("must be a list"), do: dgettext("errors", "must be a list")
  defp translate("has invalid format"), do: dgettext("errors", "has invalid format")
  defp translate("has an unsupported type"), do: dgettext("errors", "has an unsupported type")

  defp translate("must be a date like 2026-10-31"),
    do: dgettext("errors", "must be a date like 2026-10-31")

  defp translate("must be a month like 2026-10"),
    do: dgettext("errors", "must be a month like 2026-10")

  defp translate(message) do
    cond do
      match = Regex.run(~r/^must be at most (\d+) characters$/, message) ->
        dgettext("errors", "must be at most %{max} characters", max: List.last(match))

      match = Regex.run(~r/^must have at most (\d+) rows$/, message) ->
        dgettext("errors", "must have at most %{max} rows", max: List.last(match))

      match = Regex.run(~r/^must be at most (.+)$/, message) ->
        dgettext("errors", "must be at most %{max}", max: List.last(match))

      match = Regex.run(~r/^must be at least (.+)$/, message) ->
        dgettext("errors", "must be at least %{min}", min: List.last(match))

      match = Regex.run(~r/^must be one of: (.+)$/, message) ->
        dgettext("errors", "must be one of: %{options}", options: List.last(match))

      true ->
        message
    end
  end

  @doc false
  def changeset_messages do
    [
      dgettext_noop("errors", "must have the @ sign and no spaces"),
      dgettext_noop("errors", "did not change"),
      dgettext_noop("errors", "does not match password"),
      dgettext_noop("errors", "at least one lower case character"),
      dgettext_noop("errors", "at least one upper case character"),
      dgettext_noop("errors", "at least one digit or punctuation character")
    ]
  end
end
