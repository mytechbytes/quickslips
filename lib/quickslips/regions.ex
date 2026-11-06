defmodule QuickSlips.Regions do
  @moduledoc """
  What the country and the currency of a document decide: how numbers are grouped, where the currency sign
  goes, which way round a date is written. The words of a document are not here; they come from the
  language (see `QuickSlips.Templates`). The language, the country and the currency are chosen apart, so a
  Spanish document for India is allowed.

  The data is in `priv/regions`: one file per country in `countries/` and `currencies.json`. It is read
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

  @doc "The currency a country uses unless the document says otherwise, like `\"INR\"`."
  def default_currency(country) do
    case @countries do
      %{^country => %{"currency" => currency}} -> currency
      _ -> nil
    end
  end

  @doc """
  The region of a document: a map with string keys, which is also the `region.json` that the Typst helpers
  read. `currency` is the code of the currency, or `nil` for the country's own.

      iex> {:ok, region} = QuickSlips.Regions.build("es", nil)
      iex> region["currency"]
      %{"code" => "EUR", "symbol" => "€", "decimals" => 2}
  """
  def build(country, currency \\ nil) do
    with {:ok, data} <- fetch(@countries, country, :unknown_country),
         code = currency || data["currency"],
         {:ok, money} <- fetch(@currencies, code, :unknown_currency) do
      {:ok,
       %{
         "country" => data["code"],
         "currency" => Map.put(money, "code", code),
         "number" => data["number"],
         "money" => data["money"],
         "date" => data["date"]
       }}
    end
  end

  defp fetch(map, key, error) when is_binary(key) do
    case map do
      %{^key => value} -> {:ok, value}
      _ -> {:error, error}
    end
  end

  defp fetch(_map, _key, error), do: {:error, error}
end
