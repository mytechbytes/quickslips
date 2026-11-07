defmodule QuickSlips.Templates.Validator do
  @moduledoc """
  Checks submitted data against the `fields` list in a template's schema.

  Returns `{:ok, clean}` (only known fields, trimmed, optional blanks removed) or
  `{:error, {:validation, %{"field_key" => ["message"]}}}`.

  A field of type `items` is a list of rows (`name`, `qty`, `rate`). A row with nothing in it is left out; a row
  with something in it is checked cell by cell, and an error is named after the cell: `"items.2.qty"` is the
  quantity of the third row of the list that was sent. The amount of a row is not kept: it is quantity times rate,
  worked out where the document is made.
  """

  def validate(%{"fields" => fields}, data) when is_map(data) do
    {clean, errors} =
      Enum.reduce(fields, {%{}, %{}}, fn field, {clean, errors} ->
        key = field["key"]

        case validate_field(field, Map.get(data, key)) do
          :skip -> {clean, errors}
          {:ok, value} -> {Map.put(clean, key, value), errors}
          {:error, message} -> {clean, Map.put(errors, key, [message])}
          {:errors, found} -> {clean, Map.merge(errors, found)}
        end
      end)

    if errors == %{}, do: {:ok, clean}, else: {:error, {:validation, errors}}
  end

  def validate(_schema, _data), do: {:error, {:validation, %{"data" => ["must be an object"]}}}

  defp validate_field(%{"type" => "items"} = field, value), do: validate_items(field, value)

  defp validate_field(field, value) do
    cond do
      blank?(value) and field["required"] == true -> {:error, "is required"}
      blank?(value) -> :skip
      true -> check(field, value)
    end
  end

  @max_rows 50

  defp validate_items(field, value) do
    key = field["key"]
    max = field["max_rows"] || @max_rows

    cond do
      blank?(value) and field["required"] == true -> {:error, "is required"}
      blank?(value) -> :skip
      not is_list(value) -> {:error, "must be a list"}
      length(value) > max -> {:error, "must have at most #{max} rows"}
      true -> check_rows(field, key, value)
    end
  end

  defp check_rows(field, key, rows) do
    {clean, errors} =
      rows
      |> Enum.with_index()
      |> Enum.reduce({[], %{}}, fn {row, index}, {clean, errors} ->
        case check_row(field, row) do
          :blank -> {clean, errors}
          {:ok, row} -> {[row | clean], errors}
          {:error, found} -> {clean, Map.merge(errors, prefix(found, "#{key}.#{index}"))}
        end
      end)

    cond do
      errors != %{} -> {:errors, errors}
      clean == [] and field["required"] == true -> {:error, "is required"}
      clean == [] -> :skip
      true -> {:ok, Enum.reverse(clean)}
    end
  end

  # The cells of a row, and what each may hold.
  defp check_row(field, %{} = row) do
    columns = [
      {"name", %{"type" => "text", "max_length" => field["name_max_length"] || 80}},
      {"qty", %{"type" => "number", "min" => field["qty_min"] || 0.01}},
      {"rate", %{"type" => "number", "min" => field["rate_min"] || 0}}
    ]

    if Enum.all?(columns, fn {column, _spec} -> blank?(Map.get(row, column)) end) do
      :blank
    else
      {clean, errors} =
        Enum.reduce(columns, {%{}, %{}}, fn {column, spec}, {clean, errors} ->
          case validate_field(Map.put(spec, "required", true), Map.get(row, column)) do
            {:ok, value} -> {Map.put(clean, column, value), errors}
            {:error, message} -> {clean, Map.put(errors, column, [message])}
          end
        end)

      if errors == %{}, do: {:ok, clean}, else: {:error, errors}
    end
  end

  defp check_row(_field, _row), do: {:error, %{"" => ["must be an object"]}}

  defp prefix(errors, path) do
    Map.new(errors, fn
      {"", messages} -> {path, messages}
      {column, messages} -> {"#{path}.#{column}", messages}
    end)
  end

  defp upcase(value, true), do: String.upcase(value)
  defp upcase(value, _no), do: value

  defp matches?(nil, _value), do: true
  defp matches?(pattern, value), do: Regex.match?(Regex.compile!(pattern), value)

  defp blank?(nil), do: true
  defp blank?(value) when is_binary(value), do: String.trim(value) == ""
  defp blank?(_value), do: false

  # `tax_id` is a text field that is written in capitals and checked against the pattern of the country (the
  # localized schema carries it); `pattern` on a text field does the same with its own pattern.
  defp check(%{"type" => type} = field, value) when type in ["text", "textarea", "tax_id"] do
    max = field["max_length"]
    # Spaces at the ends (a pasted number) do not count.
    value = if is_binary(value), do: String.trim(value), else: value

    cond do
      not is_binary(value) ->
        {:error, "must be text"}

      is_integer(max) and String.length(value) > max ->
        {:error, "must be at most #{max} characters"}

      true ->
        value = upcase(value, field["uppercase"] || type == "tax_id")

        if matches?(field["pattern"], value),
          do: {:ok, value},
          else: {:error, "has invalid format"}
    end
  end

  # A tax rate is a percentage. The country's own rates are offered by the form, but any percentage is kept: a
  # saved document may carry a rate that has since changed.
  defp check(%{"type" => "tax_rate"}, value),
    do: check(%{"type" => "number", "min" => 0, "max" => 100}, value)

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
