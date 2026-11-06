defmodule QuickSlips.Regions do
  @moduledoc """
  What the country and the currency of a document decide: how numbers are grouped, where the currency sign
  goes, which way round a date is written. The words of a document are not here; they come from the
  language (see `QuickSlips.Templates`). The language, the country and the currency are chosen apart, so a
  Spanish document for India is allowed.

  The data is in `priv/regions`: one file per country in `countries/` and `currencies.json`. A country's `tax` says
  how its tax is called, which rates a bill offers, and how a tax-registration number looks; each carries the
  date it was checked and where (take rates from the tax authority, not from memory). It is read
  when this module compiles, and a new country file makes it compile again.
  """

  @root Path.expand("../../priv/regions", __DIR__)
  @currencies_file Path.join(@root, "currencies.json")
  @country_files Path.wildcard(Path.join(@root, "countries/*.json"))

  for file <- [@currencies_file | @country_files], do: @external_resource(file)

  @countries Map.new(@country_files, fn file ->
               country = file |> File.read!() |> Jason.decode!()
               {country["code"], country}
             end)

  @currencies @currencies_file |> File.read!() |> Jason.decode!()

  @files_hash :erlang.md5(Enum.sort(@country_files))

  # Mix asks this when a file is added to or removed from `countries/`, which `@external_resource` can't see.
  def __mix_recompile__? do
    Path.wildcard(Path.join(@root, "countries/*.json")) |> Enum.sort() |> :erlang.md5() !=
      @files_hash
  end

  @doc "The codes of the countries that have a file, like `[\"es\", \"in\"]`."
  def countries, do: @countries |> Map.keys() |> Enum.sort()

  @doc "The currencies a document may use: `[%{\"code\" => \"EUR\", \"symbol\" => \"€\"}, ...]` by code."
  def currencies do
    @currencies
    |> Enum.map(fn {code, money} -> Map.put(money, "code", code) end)
    |> Enum.sort_by(& &1["code"])
  end

  @doc "The currency a country uses unless the document says otherwise, like `\"INR\"`."
  def default_currency(country) do
    case @countries do
      %{^country => %{"currency" => currency}} -> currency
      _ -> nil
    end
  end

  @doc """
  An address and a tax-registration number written the way the country writes them, for the sample a form starts
  with: `%{"address" => "...", "tax_id" => "..."}`, or `nil` for a country without examples (India, whose
  examples are the ones in every template's own sample).
  """
  def example(country) do
    case @countries do
      %{^country => %{"example" => example}} -> example
      _ -> nil
    end
  end

  @doc """
  The region of a document: a map with string keys, which is also the `region.json` that the Typst helpers
  read. `currency` is the code of the currency, or `nil` for the country's own; `language` picks the names
  of the tax where a country has more than one.

      iex> {:ok, region} = QuickSlips.Regions.build("es", nil)
      iex> region["currency"]
      %{"code" => "EUR", "symbol" => "€", "decimals" => 2}
  """
  def build(country, currency \\ nil, language \\ nil) do
    with {:ok, data} <- fetch(@countries, country, :unknown_country),
         code = currency || data["currency"],
         {:ok, money} <- fetch(@currencies, code, :unknown_currency) do
      # A country with two languages may write numbers and money differently in each (French Canada).
      data = Map.merge(data, get_in(data, ["by_language", language]) || %{})

      {:ok,
       %{
         "country" => data["code"],
         "currency" => Map.put(money, "code", code),
         "number" => data["number"],
         "money" => data["money"],
         "date" => data["date"],
         "tax" => localize_tax(data["tax"], language)
       }}
    end
  end

  # What the tax and its registration number are called may differ by language: `"name": {"en": "VAT", "fr": "TVA"}`.
  defp localize_tax(nil, _language), do: nil

  defp localize_tax(tax, language) do
    tax
    |> Map.update!("name", &pick(&1, language))
    |> update_in(["id", "label"], &pick(&1, language))
  end

  defp pick(%{} = names, language),
    do: names[language] || names["en"] || names |> Map.values() |> hd()

  defp pick(name, _language), do: name

  defp fetch(map, key, error) when is_binary(key) do
    case map do
      %{^key => value} -> {:ok, value}
      _ -> {:error, error}
    end
  end

  defp fetch(_map, _key, error), do: {:error, error}
end
