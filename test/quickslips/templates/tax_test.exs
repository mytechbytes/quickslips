defmodule QuickSlips.Templates.TaxTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Locales
  alias QuickSlips.Templates
  alias QuickSlips.Templates.Validator

  defp schema(slug, locale), do: elem(Templates.get(slug, Locales.fetch!(locale)), 1)
  defp field(schema, key), do: Enum.find(schema["fields"], &(&1["key"] == key))

  describe "what a country adds to a bill" do
    test "the Fuel Bill has a tax rate only where the country taxes fuel at sale, with that country's rates" do
      assert field(schema("fuel-bill", "es-es"), "tax_percent")["rates"] == [0, 4, 10, 21]
      assert field(schema("fuel-bill", "en-in"), "tax_percent") == nil
      assert field(schema("fuel-bill", "hi-in"), "tax_percent") == nil
    end

    test "a tax id is checked against the pattern of the country" do
      assert field(schema("fuel-bill", "en-in"), "seller_tax_id")["pattern"] =~ "Z[0-9A-Z]"
      assert field(schema("fuel-bill", "es-es"), "seller_tax_id")["pattern"] =~ "XYZ"
    end

    test "GST on India's bills offers the rates of GST 2.0" do
      for slug <- ["restaurant-bill", "service-invoice", "hotel-invoice"] do
        assert field(schema(slug, "en-in"), "gst_percent") |> Map.take(["type", "rates"]) ==
                 %{"type" => "tax_rate", "rates" => [0, 5, 18, 40]}
      end
    end
  end

  describe "validating" do
    test "a tax id is written in capitals, and a wrong one is refused" do
      india = schema("fuel-bill", "en-in")
      sample = elem(Templates.sample("fuel-bill"), 1)

      assert {:ok, %{"seller_tax_id" => "24ABCDE1234F1Z5"}} =
               Validator.validate(india, Map.put(sample, "seller_tax_id", " 24abcde1234f1z5 "))

      assert {:error, {:validation, %{"seller_tax_id" => ["has invalid format"]}}} =
               Validator.validate(india, Map.put(sample, "seller_tax_id", "B41234567"))

      spain = schema("fuel-bill", "es-es")
      sample = elem(Templates.sample("fuel-bill", Locales.fetch!("es-es")), 1)

      assert {:ok, %{"seller_tax_id" => "B41234567"}} = Validator.validate(spain, sample)

      assert {:error, {:validation, %{"seller_tax_id" => ["has invalid format"]}}} =
               Validator.validate(spain, Map.put(sample, "seller_tax_id", "24ABCDE1234F1Z5"))
    end

    test "a tax rate is any percentage, so a rate that has changed still works" do
      schema = schema("restaurant-bill", "en-in")
      {:ok, sample} = Templates.sample("restaurant-bill")

      for rate <- [0, 5, 12, 28.5] do
        assert {:ok, %{"gst_percent" => ^rate}} =
                 Validator.validate(schema, Map.put(sample, "gst_percent", rate))
      end

      for rate <- [-1, 101, "five"] do
        assert {:error, {:validation, %{"gst_percent" => [_]}}} =
                 Validator.validate(schema, Map.put(sample, "gst_percent", rate))
      end
    end

    test "the FSSAI number of a food bill has 14 digits, and may be left out" do
      schema = schema("restaurant-bill", "en-in")
      {:ok, sample} = Templates.sample("restaurant-bill")

      assert {:ok, %{"fssai_number" => "11224999000123"}} = Validator.validate(schema, sample)
      assert {:ok, clean} = Validator.validate(schema, Map.delete(sample, "fssai_number"))
      refute Map.has_key?(clean, "fssai_number")

      for bad <- ["1122499900012", "1122499900012A", "11 22499900012"] do
        assert {:error, {:validation, %{"fssai_number" => ["has invalid format"]}}} =
                 Validator.validate(schema, Map.put(sample, "fssai_number", bad))
      end
    end

    test "a field of another country is not part of the bill: it is not asked for, and not kept" do
      india = schema("fuel-bill", "en-in")
      {:ok, sample} = Templates.sample("fuel-bill")

      assert {:ok, clean} = Validator.validate(india, Map.put(sample, "tax_percent", 21))
      refute Map.has_key?(clean, "tax_percent")
    end
  end
end
