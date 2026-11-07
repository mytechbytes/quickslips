defmodule QuickSlips.RegionsTest do
  use ExUnit.Case, async: true

  doctest QuickSlips.Regions

  alias QuickSlips.Regions

  test "countries/0 lists the countries that have a file" do
    assert Regions.countries() == ~w(br ca cn de es fr gb in it jp us)
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

  describe "the ten largest economies" do
    @nif_free ~w(us cn de jp gb fr it br ca in es)

    test "every country has formats, a currency that exists and a checked tax section" do
      for country <- @nif_free do
        assert {:ok, region} = Regions.build(country)
        assert region["currency"]["symbol"] != nil, country
        assert region["date"]["order"] in ["dmy", "mdy", "ymd"], country
        assert %{"name" => _, "rates" => rates, "id" => %{"pattern" => pattern}} = region["tax"]
        assert is_list(rates) and Enum.all?(rates, &is_number/1), country
        assert {:ok, _} = Regex.compile(pattern), country
      end
    end

    test "the formats of each: Japan has no decimals, France groups with a narrow space, Germany writes day.month.year" do
      assert {:ok, %{"currency" => %{"code" => "JPY", "decimals" => 0}}} = Regions.build("jp")
      assert {:ok, %{"number" => %{"group" => "\u202f", "decimal" => ","}}} = Regions.build("fr")
      assert {:ok, %{"date" => %{"order" => "dmy", "separator" => "."}}} = Regions.build("de")
      assert {:ok, %{"date" => %{"order" => "mdy"}}} = Regions.build("us")
    end

    test "Canada writes numbers and money differently in French" do
      {:ok, english} = Regions.build("ca", nil, "en")
      {:ok, french} = Regions.build("ca", nil, "fr")

      assert english["number"]["decimal"] == "." and english["money"]["position"] == "before"
      assert french["number"]["decimal"] == "," and french["money"]["position"] == "after"
      assert english["tax"]["name"] == "GST/HST" and french["tax"]["name"] == "TPS/TVH"
      assert french["tax"]["id"]["label"] == "N° TPS/TVH"
    end

    test "the name of a tax follows the language, and falls back to English" do
      assert {:ok, %{"tax" => %{"name" => "增值税"}}} = Regions.build("cn", nil, "zh")
      assert {:ok, %{"tax" => %{"name" => "VAT"}}} = Regions.build("cn", nil, "hi")
      assert {:ok, %{"tax" => %{"name" => "VAT"}}} = Regions.build("gb")
    end

    test "the United States and Brazil have no rate to offer: it is typed" do
      for country <- ["us", "br"],
          do: assert({:ok, %{"tax" => %{"rates" => []}}} = Regions.build(country))
    end

    test "the tax ids match their shape" do
      id = fn country, value ->
        {:ok, %{"tax" => %{"id" => %{"pattern" => pattern}}}} = Regions.build(country)
        Regex.match?(Regex.compile!(pattern), value)
      end

      assert id.("de", "DE123456789") and not id.("de", "123456789")
      assert id.("jp", "T1234567890123") and not id.("jp", "1234567890123")

      assert id.("fr", "FR12345678901") and id.("it", "IT01234567890") and
               id.("it", "01234567890")

      assert id.("gb", "GB123456789") and id.("gb", "123456789012")
      assert id.("ca", "123456789RT0001") and id.("ca", "123456789") and not id.("ca", "12345678")
      assert id.("us", "12-3456789") and id.("us", "123456789")
      assert id.("br", "12.345.678/0001-90") and id.("br", "12345678000190")
      assert id.("cn", "91110000600037341L")
    end
  end
end
