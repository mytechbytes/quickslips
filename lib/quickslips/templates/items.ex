defmodule QuickSlips.Templates.Items do
  @moduledoc """
  Documents made before a bill had a table of items kept their rows as numbered fields (`item_1`, `qty_1`,
  `price_1`, ...). A field of type `items` holds them as a list of rows instead: `[%{"name" => _, "qty" => _,
  "rate" => _}]`.

  A schema says how the old fields were named, in `"legacy"` on the `items` field:

      %{"key" => "items", "type" => "items", "legacy" => %{"name" => "item", "qty" => "qty", "rate" => "price", "count" => 6}}

  `upgrade/2` makes the new shape of the old data, so a saved document, or a page that was open before the change,
  keeps working.
  """

  @doc "The data with each `items` field that is missing filled in from the numbered fields of the old shape."
  def upgrade(schema, data) when is_map(data) do
    Enum.reduce(schema["fields"], data, fn
      %{"type" => "items", "key" => key, "legacy" => legacy}, data ->
        if Map.has_key?(data, key), do: data, else: upgrade_field(data, key, legacy)

      _field, data ->
        data
    end)
  end

  def upgrade(_schema, data), do: data

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
