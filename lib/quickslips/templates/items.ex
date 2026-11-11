defmodule QuickSlips.Templates.Items do
  @moduledoc """
  Documents made before a bill had a table of items kept their rows as numbered fields (`item_1`, `qty_1`,
  `price_1`, ...). A field of type `items` holds them as a list of rows instead: `[%{"name" => _, "qty" => _,
  "rate" => _}]`.

  A schema says how the old fields were named, in `"legacy"` on the `items` field:

      %{"key" => "items", "type" => "items", "legacy" => %{"name" => "item", "qty" => "qty", "rate" => "price", "count" => 6}}

  `upgrade/2` makes the new shape of the old data, so a saved document, or a page that was open before the change,
  keeps working.

  A field of type `periods` replaced the fields `month`, `from_date`, `to_date`, `bill_by` and `receipt_date` of
  the salary receipt; `upgrade/2` makes the period of a document that has them (a period that ran over several
  months, billed monthly, becomes those months, up to 12).
  """

  @doc "The data with each `items` field that is missing filled in from the numbered fields of the old shape."
  def upgrade(schema, data) when is_map(data) do
    Enum.reduce(schema["fields"], data, fn
      %{"type" => "items", "key" => key, "legacy" => legacy}, data ->
        if Map.has_key?(data, key), do: data, else: upgrade_field(data, key, legacy)

      %{"type" => "periods", "key" => key}, data ->
        if Map.has_key?(data, key), do: data, else: upgrade_periods(data, key)

      _field, data ->
        data
    end)
  end

  def upgrade(_schema, data), do: data

  defp upgrade_periods(%{"month" => month} = data, key) when is_binary(month) do
    by = data["bill_by"] || "Monthly"
    last = present(data["to_date"]) && String.slice(data["to_date"], 0, 7)
    first = (present(data["from_date"]) && String.slice(data["from_date"], 0, 7)) || month

    months =
      if by == "Monthly" and last != nil and last > first,
        do: months_between(first, last),
        else: [first]

    periods = %{"bill_by" => by, "months" => months, "dates" => [data["receipt_date"] || ""]}

    data
    |> Map.drop(["month", "from_date", "to_date", "bill_by", "receipt_date"])
    |> Map.put(key, periods)
  end

  defp upgrade_periods(data, _key), do: data

  defp months_between(first, last) do
    [fy, fm] = first |> String.split("-") |> Enum.map(&String.to_integer/1)
    [ly, lm] = last |> String.split("-") |> Enum.map(&String.to_integer/1)
    count = min((ly - fy) * 12 + lm - fm + 1, 12)

    for i <- 0..(count - 1) do
      index = fy * 12 + fm - 1 + i

      "#{div(index, 12)}-#{index |> rem(12) |> Kernel.+(1) |> Integer.to_string() |> String.pad_leading(2, "0")}"
    end
  end

  defp upgrade_field(data, key, %{"name" => name, "qty" => qty, "rate" => rate, "count" => count}) do
    numbered = for i <- 1..count, field <- [name, qty, rate], do: "#{field}_#{i}"

    rows =
      for i <- 1..count, name_value = present(data["#{name}_#{i}"]), name_value != nil do
        %{
          "name" => name_value,
          "qty" => data["#{qty}_#{i}"] || 1,
          "rate" => data["#{rate}_#{i}"] || 0
        }
      end

    if rows == [] and not Enum.any?(numbered, &Map.has_key?(data, &1)),
      do: data,
      else: data |> Map.drop(numbered) |> Map.put(key, rows)
  end

  defp present(value) when is_binary(value) and value != "", do: value
  defp present(_value), do: nil
end
