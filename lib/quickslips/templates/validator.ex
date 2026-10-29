defmodule QuickSlips.Templates.Validator do
  @moduledoc """
  Checks submitted data against the `fields` list in a template's schema.

  Returns `{:ok, clean}` (only known fields, trimmed, optional blanks removed) or
  `{:error, {:validation, %{"field_key" => ["message"]}}}`.
  """

  def validate(%{"fields" => fields}, data) when is_map(data) do
    {clean, errors} =
      Enum.reduce(fields, {%{}, %{}}, fn field, {clean, errors} ->
        key = field["key"]

        case validate_field(field, Map.get(data, key)) do
          :skip -> {clean, errors}
          {:ok, value} -> {Map.put(clean, key, value), errors}
          {:error, message} -> {clean, Map.put(errors, key, [message])}
        end
      end)

    if errors == %{}, do: {:ok, clean}, else: {:error, {:validation, errors}}
  end

  def validate(_schema, _data), do: {:error, {:validation, %{"data" => ["must be an object"]}}}

  defp validate_field(field, value) do
    cond do
      blank?(value) and field["required"] == true -> {:error, "is required"}
      blank?(value) -> :skip
      true -> check(field, value)
    end
  end

  defp blank?(nil), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_value), do: false

  defp check(%{"type" => type} = field, value) when type in ["text", "textarea"] do
    max = field["max_length"]

    cond do
      not is_binary(value) ->
        {:error, "must be text"}

      is_integer(max) and String.length(value) > max ->
        {:error, "must be at most #{max} characters"}

      true ->
        {:ok, String.trim(value)}
    end
  end

  defp check(%{"type" => "number"} = field, value) do
    cond do
      not is_number(value) ->
        {:error, "must be a number"}

      is_number(field["min"]) and value < field["min"] ->
        {:error, "must be at least #{field["min"]}"}

      is_number(field["max"]) and value > field["max"] ->
        {:error, "must be at most #{field["max"]}"}

      true ->
        {:ok, value}
    end
  end

  defp check(%{"type" => "date"}, value) do
    with true <- is_binary(value),
         {:ok, _date} <- Date.from_iso8601(value) do
      {:ok, value}
    else
      _ -> {:error, "must be a date like 2026-10-31"}
    end
  end

  defp check(%{"type" => "month"}, value) do
    if is_binary(value) and Regex.match?(~r/^\d{4}-(0[1-9]|1[0-2])$/, value),
      do: {:ok, value},
      else: {:error, "must be a month like 2026-10"}
  end

  defp check(%{"type" => "select", "options" => options}, value) do
    if value in options,
      do: {:ok, value},
      else: {:error, "must be one of: #{Enum.join(options, ", ")}"}
  end

  defp check(_field, _value), do: {:error, "has an unsupported type"}
end
