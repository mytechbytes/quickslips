defmodule QuickSlips.RegionsTest do
  use ExUnit.Case, async: true

  doctest QuickSlips.Regions

  alias QuickSlips.Regions

  test "countries/0 lists the countries that have a file" do
    assert Regions.countries() == ["es", "in"]
  end

  test "India: rupees, Indian grouping, the sign before the amount" do
    assert {:ok, region} = Regions.build("in")

    assert Map.delete(region, "tax") == %{
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

  describe "tax" do
    test "India: GST, the rates since GST 2.0, and the GSTIN" do
      {:ok, %{"tax" => tax}} = Regions.build("in")

      assert %{"name" => "GST", "rates" => [0, 5, 18, 40], "id" => %{"label" => "GSTIN"}} = tax
      assert gstin = Regex.compile!(tax["id"]["pattern"])
      assert Regex.match?(gstin, "24ABCDE1234F1Z5")
      refute Regex.match?(gstin, "24ABCDE1234F1Z")
      refute Regex.match?(gstin, "24abcde1234f1z5")
    end

    test "Spain: IVA at 0, 4, 10 and 21, and the three shapes of a NIF" do
      {:ok, %{"tax" => tax}} = Regions.build("es")

      assert %{"name" => "IVA", "rates" => [0, 4, 10, 21], "id" => %{"label" => "NIF"}} = tax
      nif = Regex.compile!(tax["id"]["pattern"])

      for ok <- ["12345678Z", "X1234567L", "B41234567", "Q2826000H"],
          do: assert(Regex.match?(nif, ok), ok)

      for bad <- ["1234567Z", "12345678", "I41234567", "b41234567", ""],
          do: refute(Regex.match?(nif, bad), bad)
    end

    test "every country says when and where its tax was checked" do
      for country <- Regions.countries() do
        {:ok, %{"tax" => tax}} = Regions.build(country)

        assert tax["checked"] =~ ~r/^\d{4}-\d{2}-\d{2}$/
        assert [_ | _] = tax["sources"]
        assert Enum.all?(tax["sources"], &String.starts_with?(&1, "https://"))
      end
    end
  end
end
