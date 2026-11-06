defmodule QuickSlips.RegionsTest do
  use ExUnit.Case, async: true

  doctest QuickSlips.Regions

  alias QuickSlips.Regions

  test "countries/0 lists the countries that have a file" do
    assert Regions.countries() == ["es", "in"]
  end

  test "India: rupees, Indian grouping, the sign before the amount" do
    assert {:ok, region} = Regions.build("in")

    assert region == %{
             "country" => "in",
             "currency" => %{"code" => "INR", "symbol" => "₹", "decimals" => 2},
             "number" => %{"decimal" => ".", "group" => ",", "grouping" => "indian"},
             "money" => %{"position" => "before", "space" => true},
             "date" => %{"order" => "dmy", "separator" => "/"}
           }
  end

  test "Spain: euros, a comma for the decimals, the sign after the amount" do
    assert {:ok, region} = Regions.build("es")

    assert region["currency"] == %{"code" => "EUR", "symbol" => "€", "decimals" => 2}
    assert region["number"] == %{"decimal" => ",", "group" => ".", "grouping" => "standard"}
    assert region["money"] == %{"position" => "after", "space" => true}
  end

  test "a document may use a currency that is not its country's" do
    assert {:ok, region} = Regions.build("in", "EUR")

    assert region["currency"]["code"] == "EUR"
    # ...while the numbers are still written the Indian way.
    assert region["number"]["grouping"] == "indian"
  end

  test "default_currency/1" do
    assert Regions.default_currency("in") == "INR"
    assert Regions.default_currency("es") == "EUR"
    assert Regions.default_currency("zz") == nil
  end

  test "unknown countries and currencies are errors, not crashes" do
    assert {:error, :unknown_country} = Regions.build("zz")
    assert {:error, :unknown_country} = Regions.build(nil)
    assert {:error, :unknown_currency} = Regions.build("in", "XXX")
    assert {:error, :unknown_currency} = Regions.build("in", 5)
  end
end
