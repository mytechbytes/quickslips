defmodule QuickSlips.Templates.Validator do
  @moduledoc """
  Checks submitted data against the `fields` list in a template's schema.

  Returns `{:ok, clean}` (only known fields, trimmed, optional blanks removed) or
  `{:error, {:validation, %{"field_key" => ["message"]}}}`.

  A field of type `periods` is the period a salary or rent receipt is for: `%{"bill_by" => "Monthly", "months" =>
  ["2026-07", "2026-08"], "dates" => ["2026-07-31", ""]}`. `bill_by` is one of the field's `"options"` (Monthly,
  Quarterly, Half-yearly, Yearly). Billed monthly it lists 1 to 12 months (a receipt for each); billed by a longer
  period it names the one month the period starts in (one receipt covers the whole period). `dates` holds the date of
  each receipt (`""` for none), whatever was sent, cut or filled out to the number of receipts.

  A field of type `items` is a list of rows. A row has the cells the field names in `"cells"` (`["name", "qty",
  "rate"]` unless it says otherwise): `name`, `qty`, `rate`, and for a table of parts or jobs a `code`, a `billing`
  type (one of the field's `"billing_options"`), a `discount` and a `tax` rate in percent, and the short text cells `hsn`,
  `mfr`, `batch`, `expiry` and `schedule` of a table of goods. A row with nothing in it is left out
  (a choice that has a default, like `billing`, is not something); a row with something in it is checked cell by
  cell, and an error is named after the cell: `"items.2.qty"` is the quantity of the third row of the list that
  was sent. The amount of a row is not kept: it is quantity times rate less the discount, worked out where the
  document is made.
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
  defp validate_field(%{"type" => "periods"} = field, value), do: validate_periods(field, value)

  defp validate_field(field, value) do
    cond do
      blank?(value) and field["required"] == true -> {:error, "is required"}
      blank?(value) -> :skip
      true -> check(field, value)
    end
  end

  @max_rows 50

  @max_months 12
  @max_years 10
  # The months a period of each kind covers: a receipt is made for each period chosen, and `months` holds the month each starts in.
  @steps %{"Monthly" => 1, "Quarterly" => 3, "Half-yearly" => 6, "Yearly" => 12}

  defp validate_periods(field, value) do
    cond do
      blank?(value) and field["required"] == true -> {:error, "is required"}
      blank?(value) -> :skip
      not is_map(value) -> {:error, "must be an object"}
      true -> check_periods(field, value)
    end
  end

  defp check_periods(field, value) do
    by = Map.get(value, "bill_by", "Monthly")
    options = field["options"] || ["Monthly"]
    months = value["months"]

    cond do
      by not in options ->
        {:error, "bill by must be one of: #{Enum.join(options, ", ")}"}

      not (is_list(months) and Enum.all?(months, &valid_month?/1)) ->
        {:error, "months must be like 2026-10"}

      months == [] or length(Enum.uniq(months)) > max_periods(by) ->
        {:error, "choose from 1 to #{max_periods(by)} periods"}

      by != "Yearly" and not within_a_year?(months) ->
        {:error, "the periods must fall within twelve months"}

      true ->
        months = months |> Enum.uniq() |> Enum.sort()
        receipts = length(months)

        case clean_dates(value["dates"], receipts) do
          {:ok, dates} -> {:ok, %{"bill_by" => by, "months" => months, "dates" => dates}}
          :error -> {:error, "dates must be like 2026-10-31"}
        end
    end
  end

  # A year or less of months for the shorter periods; billed by the year, one receipt for each of up to ten years.
  defp max_periods("Yearly"), do: @max_years
  defp max_periods(by), do: div(@max_months, Map.get(@steps, by, 1))

  defp within_a_year?(months) do
    indexes =
      for <<year::binary-size(4), "-", month::binary-size(2)>> <- months,
          do: String.to_integer(year) * 12 + String.to_integer(month)

    Enum.max(indexes) - Enum.min(indexes) < @max_months
  end

  defp valid_month?(month),
    do: is_binary(month) and Regex.match?(~r/^\d{4}-(0[1-9]|1[0-2])$/, month)

  # One date or "" for each receipt; the list sent is cut or filled out to the number of receipts.
  defp clean_dates(dates, receipts) do
    list = if is_list(dates), do: dates, else: []

    cleaned =
      for date <- Enum.take(list ++ List.duplicate("", receipts), receipts) do
        cond do
          blank?(date) -> {:ok, ""}
          is_binary(date) and match?({:ok, _}, Date.from_iso8601(date)) -> {:ok, date}
          true -> :error
        end
      end

    if Enum.all?(cleaned, &match?({:ok, _}, &1)),
      do: {:ok, Enum.map(cleaned, &elem(&1, 1))},
      else: :error
  end

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

  @default_cells ["name", "qty", "rate"]

  # What each cell of a row may hold, in the order of the field's `"cells"`, and whether a row must have it.
  defp cell_specs(field) do
    for cell <- field["cells"] || @default_cells do
      case cell do
        "name" ->
          {"name", %{"type" => "text", "max_length" => field["name_max_length"] || 80}, true}

        "code" ->
          {"code", %{"type" => "text", "max_length" => field["code_max_length"] || 30}, false}

        # short text cells of a table of goods: the HSN code, the manufacturer, the batch, the expiry, the schedule
        cell when cell in ["hsn", "mfr", "batch", "expiry", "schedule"] ->
          {cell, %{"type" => "text", "max_length" => field["cell_max_length"] || 30}, false}

        "billing" ->
          {"billing", %{"type" => "select", "options" => field["billing_options"] || []}, false}

        "qty" ->
          {"qty", %{"type" => "number", "min" => field["qty_min"] || 0.01}, true}

        "rate" ->
          {"rate", %{"type" => "number", "min" => field["rate_min"] || 0}, true}

        "discount" ->
          {"discount", %{"type" => "number", "min" => 0, "max" => 100}, false}

        "tax" ->
          {"tax", %{"type" => "number", "min" => 0, "max" => 100}, false}
      end
    end
  end

  defp check_row(field, %{} = row) do
    specs = cell_specs(field)

    # A select has a value from the start, so a row with only that is a row nobody filled in.
    if Enum.all?(specs, fn {cell, spec, _required} ->
         spec["type"] == "select" or blank?(Map.get(row, cell))
       end) do
      :blank
    else
      {clean, errors} =
        Enum.reduce(specs, {%{}, %{}}, fn {cell, spec, required}, {clean, errors} ->
          case validate_field(Map.put(spec, "required", required), Map.get(row, cell)) do
            {:ok, value} -> {Map.put(clean, cell, value), errors}
            :skip -> {clean, errors}
            {:error, message} -> {clean, Map.put(errors, cell, [message])}
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

  defp check(%{"type" => "time"}, value) do
    if is_binary(value) and Regex.match?(~r/^([01]\d|2[0-3]):[0-5]\d$/, value),
      do: {:ok, value},
      else: {:error, "must be a time like 14:30"}
  end

  defp check(%{"type" => "select", "options" => options}, value) do
    if value in options,
      do: {:ok, value},
      else: {:error, "must be one of: #{Enum.join(options, ", ")}"}
  end

  defp check(_field, _value), do: {:error, "has an unsupported type"}
end
