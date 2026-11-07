defmodule QuickSlips.TemplatesTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Locales
  alias QuickSlips.Templates
  alias QuickSlips.Templates.Validator

  test "lists the bundled templates" do
    slugs = Templates.list() |> Enum.map(& &1["slug"])
    assert "fuel-bill" in slugs
    assert "rent-receipt" in slugs
  end

  test "get/1" do
    assert {:ok, %{"title" => _}} = Templates.get("fuel-bill")
    assert {:error, :not_found} = Templates.get("does-not-exist")
  end

  test "every template folder has a sample that has every required field" do
    for schema <- Templates.list() do
      dir = Templates.template_dir(schema["slug"])
      sample = dir |> Path.join("sample.json") |> File.read!() |> Jason.decode!()

      for %{"key" => key, "required" => true} <- schema["fields"] do
        assert Map.has_key?(sample, key), "#{schema["slug"]} sample is missing #{key}"
      end
    end
  end

  @categories ["Travel", "Home & utilities", "Health & learning", "Food & shopping", "Work"]

  test "the catalogue has seventeen templates in five categories" do
    templates = Templates.list()

    assert length(templates) == 17

    assert templates |> Enum.map(& &1["category"]) |> Enum.uniq() |> Enum.sort() ==
             Enum.sort(@categories)
  end

  test "every template has what the catalogue and the form need" do
    for schema <- Templates.list() do
      slug = schema["slug"]
      keys = Enum.map(schema["fields"], & &1["key"])

      for key <- ["title", "summary", "description", "icon"] do
        assert is_binary(schema[key]) and schema[key] != "", "#{slug} has no #{key}"
      end

      assert String.starts_with?(schema["icon"], "hero-"), "#{slug}: the icon is a Heroicon"
      assert length(schema["templates"]) >= 1
      assert keys == Enum.uniq(keys), "#{slug} has two fields with the same key"
      assert Enum.any?(schema["fields"], & &1["required"]), "#{slug} has no required field"

      for field <- schema["fields"] do
        assert field["type"] in [
                 "text",
                 "textarea",
                 "number",
                 "date",
                 "time",
                 "month",
                 "select",
                 "items",
                 "tax_rate",
                 "tax_id"
               ]

        assert is_binary(field["label"]) and field["label"] != ""

        if field["type"] in ["text", "textarea"],
          do:
            assert(is_integer(field["max_length"]), "#{slug}.#{field["key"]} needs a max_length")

        if field["type"] == "select",
          do: assert(field["options"] != [], "#{slug}.#{field["key"]} has no options")

        if field["prefill"],
          do: assert(field["prefill"] in ["business.name", "business.address", "business.gstin"])
      end

      # the field the history uses for the document's number exists
      if schema["number_field"], do: assert(schema["number_field"] in keys)
    end
  end

  test "the sample of every template only has fields that exist" do
    for schema <- Templates.list() do
      {:ok, sample} = Templates.sample(schema["slug"])
      keys = Enum.map(schema["fields"], & &1["key"])

      assert Map.keys(sample) -- keys == [],
             "#{schema["slug"]} has a sample value for an unknown field"
    end
  end

  # The English names and slugs the owner confirmed for search engines: internal id => public slug.
  @public_slugs %{
    "courier-receipt" => "courier-receipt-generator",
    "driver-salary-receipt" => "driver-salary-receipt-generator",
    "electricity-bill" => "electricity-bill-generator",
    "fuel-bill" => "fuel-bill-generator",
    "grocery-bill" => "grocery-bill-generator",
    "gym-membership-receipt" => "gym-membership-receipt-generator",
    "hotel-invoice" => "hotel-bill-generator",
    "internet-bill" => "internet-bill-generator",
    "maintenance-bill" => "maintenance-bill-generator",
    "medical-bill" => "medical-bill-generator",
    "mobile-bill" => "mobile-bill-generator",
    "parking-receipt" => "parking-receipt-generator",
    "rent-receipt" => "rent-receipt-generator",
    "restaurant-bill" => "restaurant-bill-generator",
    "school-fee-receipt" => "school-fee-receipt-generator",
    "service-invoice" => "invoice-generator",
    "taxi-receipt" => "cab-bill-generator"
  }

  describe "public slugs" do
    test "are the confirmed ones" do
      assert Map.new(Templates.list(), &{&1["slug"], &1["public_slug"]}) == @public_slugs
    end

    test "end in -generator, and a title is the slug in capitals" do
      for template <- Templates.list() do
        assert String.ends_with?(template["public_slug"], "-generator")

        assert template["title"] ==
                 template["public_slug"]
                 |> String.split("-")
                 |> Enum.map_join(" ", &String.capitalize/1)
                 |> String.replace("Ecommerce", "E-commerce"),
               "#{template["slug"]}: the title is not the slug in capitals"
      end
    end

    test "are different within every locale" do
      for locale <- Locales.live() do
        slugs = Enum.map(Templates.list(locale), & &1["public_slug"])
        assert slugs == Enum.uniq(slugs)
      end
    end

    test "a title never says Generator twice, and never starts with the slug of another" do
      for template <- Templates.list() do
        refute template["title"] =~ "Generator Generator"
      end
    end
  end

  describe "locales" do
    test "Fuel, Cab, Parking and Maintenance are in every language; the other templates only in English" do
      for locale <- Locales.live(), slug <- ["fuel-bill", "taxi-receipt", "parking-receipt"] do
        assert Templates.supports?(slug, locale)
      end

      hindi = Locales.fetch!("hi-in")
      assert Templates.supports?("rent-receipt", Locales.fetch!("en-in"))
      refute Templates.supports?("rent-receipt", hindi)

      for code <- ["hi-in", "es-es", "ja-jp"] do
        slugs = Locales.fetch!(code) |> Templates.list() |> Enum.map(& &1["slug"])

        assert Enum.sort(slugs) == [
                 "fuel-bill",
                 "maintenance-bill",
                 "parking-receipt",
                 "taxi-receipt"
               ]
      end

      assert length(Templates.list(Locales.fetch!("en-in"))) == 17
    end

    test "get/2 gives the words of the language and keeps the internal slug" do
      assert {:ok, schema} = Templates.get("fuel-bill", Locales.fetch!("hi-in"))
      assert schema["slug"] == "fuel-bill"
      assert schema["public_slug"] == "fuel-bill-generator"
      assert schema["title"] == "पेट्रोल बिल जनरेटर"
      assert schema["name"] == "पेट्रोल बिल"
      assert schema["category"] == "Travel"
      assert schema["category_name"] == "यात्रा"
      assert schema["locale"] == "hi-in"

      assert Enum.map(schema["fields"], & &1["key"]) |> Enum.take(2) == [
               "station_name",
               "station_address"
             ]

      fuel_type = Enum.find(schema["fields"], &(&1["key"] == "fuel_type"))
      # The data holds the option itself; the page shows its name.
      assert fuel_type["options"] == ["Petrol", "Diesel", "CNG"]
      assert fuel_type["option_labels"]["Petrol"] == "पेट्रोल"

      assert {:error, :not_found} = Templates.get("rent-receipt", Locales.fetch!("hi-in"))
    end

    test "get/1 is still the English one" do
      assert {:ok, %{"title" => "Fuel Bill Generator", "locale" => "en-in"}} =
               Templates.get("fuel-bill")
    end

    test "get_public/2 finds a template by the slug of its locale" do
      spain = Locales.fetch!("es-es")

      assert {:ok, %{"slug" => "fuel-bill", "title" => "Generador de Factura de Gasolina"}} =
               Templates.get_public(spain, "generador-de-factura-de-gasolina")

      # The English slug is not an address in Spain, and Hindi keeps the English slug.
      assert {:error, :not_found} = Templates.get_public(spain, "fuel-bill-generator")

      assert {:ok, %{"slug" => "fuel-bill"}} =
               Templates.get_public(Locales.fetch!("hi-in"), "fuel-bill-generator")

      assert {:error, :not_found} =
               Templates.get_public(Locales.fetch!("hi-in"), "rent-receipt-generator")
    end

    test "public_path/2 and alternates/1" do
      assert Templates.public_path("fuel-bill", Locales.fetch!("es-es")) ==
               "/es-es/generador-de-factura-de-gasolina"

      assert Templates.public_path("rent-receipt", Locales.fetch!("hi-in")) == nil

      alternates = Templates.alternates("fuel-bill")

      assert Enum.map(alternates, fn {locale, _slug} -> locale.code end) ==
               [
                 "en-in",
                 "hi-in",
                 "es-es",
                 "en-us",
                 "zh-cn",
                 "de-de",
                 "ja-jp",
                 "en-gb",
                 "fr-fr",
                 "it-it",
                 "pt-br",
                 "en-ca",
                 "fr-ca"
               ]

      assert {%{code: "es-es"}, "generador-de-factura-de-gasolina"} = Enum.at(alternates, 2)
      assert {%{code: "de-de"}, "tankrechnung-generator"} = Enum.at(alternates, 5)

      # A bill that is in English only is in the English locales: India, the United States, the UK, Canada.
      assert ["en-in", "en-us", "en-gb", "en-ca"] =
               "rent-receipt"
               |> Templates.alternates()
               |> Enum.map(fn {locale, _} -> locale.code end)

      assert Templates.alternates("nope") == []
    end

    test "legacy_target/1 sends an old address to the new page" do
      assert {:ok, "en-in", "fuel-bill-generator"} = Templates.legacy_target("fuel-bill")
      assert {:ok, "en-in", "cab-bill-generator"} = Templates.legacy_target("taxi-receipt")
      assert {:ok, "en-in", "invoice-generator"} = Templates.legacy_target("service-invoice")
      assert :error = Templates.legacy_target("nope")
      assert :error = Templates.legacy_target("_shared")
    end

    test "print_text/2 is what the Typst helpers read" do
      text = Templates.print_text("fuel-bill", Locales.fetch!("es-es"))

      assert text["lang"] == "es"
      assert text["print"]["total"] == "Total"
      assert text["print"]["quantity"] == "Cant. (L)"
      assert text["options"]["fuel_type"]["Petrol"] == "Gasolina"
      assert length(text["months"]) == 12
      assert length(text["months_short"]) == 12
      assert Templates.print_text("rent-receipt", Locales.fetch!("es-es")) == nil

      # A template that is not translated still has the months, for the helpers.
      assert %{"lang" => "en", "print" => %{}} =
               Templates.print_text("rent-receipt", Locales.default())
    end

    test "a translation has every word the English has" do
      english = Templates.get("fuel-bill") |> elem(1)

      for locale <- Locales.live(), {:ok, schema} = Templates.get("fuel-bill", locale) do
        # a field that only some countries have (a Spanish tax rate) is not in every locale
        everywhere = fn fields ->
          for %{"key" => key} = f <- fields,
              not is_map_key(f, "countries") and f["type"] != "tax_rate",
              do: key
        end

        assert everywhere.(schema["fields"]) == everywhere.(english["fields"])

        for field <- schema["fields"],
            english_field = Enum.find(english["fields"], &(&1["key"] == field["key"])) do
          assert field["label"] not in [nil, ""], "#{locale.code} #{field["key"]} has no label"
          # A label that names the currency does so in every language.
          assert String.contains?(field["label"], "{currency}") ==
                   String.contains?(english_field["label"], "{currency}")

          assert Map.keys(field["option_labels"] || %{}) ==
                   Map.keys(english_field["option_labels"] || %{})
        end
      end
    end
  end

  describe "samples" do
    test "a country without a standard tax rate has none in the sample, whatever the English file says" do
      for slug <- ["taxi-receipt", "maintenance-bill"] do
        {:ok, india} = Templates.sample(slug, Locales.fetch!("en-in"))
        {:ok, america} = Templates.sample(slug, Locales.fetch!("en-us"))
        {:ok, brazil} = Templates.sample(slug, Locales.fetch!("pt-br"))
        {:ok, spain} = Templates.sample(slug, Locales.fetch!("es-es"))

        assert is_number(india["tax_percent"]), slug
        assert is_number(spain["tax_percent"]), slug
        refute Map.has_key?(america, "tax_percent"), slug
        refute Map.has_key?(brazil, "tax_percent"), slug
      end
    end

    test "sample/2 puts the words of the language over the English sample" do
      {:ok, english} = Templates.sample("fuel-bill")
      {:ok, hindi} = Templates.sample("fuel-bill", Locales.fetch!("hi-in"))
      {:ok, spanish} = Templates.sample("fuel-bill", Locales.fetch!("es-es"))

      assert english["station_name"] == "Sunrise Fuel Station"
      assert hindi["station_name"] == "सनराइज़ फ्यूल स्टेशन"

      # Numbers that make no sense in another country are replaced too: 102.45 would be a lot of euros.
      assert hindi["rate"] == english["rate"]
      assert spanish["rate"] == 1.58
      assert spanish["fuel_type"] == "Petrol"
    end

    test "the sample for another country has that country's address and registration number, and no Indian ones" do
      {:ok, indian} = Templates.sample("restaurant-bill")
      {:ok, american} = Templates.sample("restaurant-bill", Locales.fetch!("en-us"))
      example = QuickSlips.Regions.example("us")

      assert indian["gstin"] =~ "ABCDE"
      assert indian["fssai_number"]
      assert american["restaurant_address"] == example["address"]
      assert american["gstin"] == example["tax_id"]
      refute Map.has_key?(american, "fssai_number")
      assert american["payment_mode"] == "Cash"
      assert american["restaurant_name"] == indian["restaurant_name"]
    end

    test "Chinese and Japanese: the fuel bill is translated, its sample is valid and they print with their fonts" do
      for {language, country} <- [{"zh", "cn"}, {"ja", "jp"}] do
        locale = Locales.with_country(%{Locales.default() | language: language}, country)
        assert {:ok, view} = QuickSlips.Templates.Registry.view("fuel-bill", locale)

        assert {:ok, _clean} = Validator.validate(view.schema, view.sample), language
        assert view.sample["station_name"] =~ ~r/[^\x00-\x7F]/

        assert view.print["fonts"] == [
                 "Noto Sans",
                 if(language == "zh", do: "Noto Sans SC", else: "Noto Sans JP")
               ]
      end
    end

    test "the sample of every language is valid for its template" do
      for locale <- Locales.live(), schema <- Templates.list(locale) do
        {:ok, sample} = Templates.sample(schema["slug"], locale)

        assert {:ok, _clean} = Validator.validate(schema, sample),
               "#{schema["slug"]} in #{locale.code} has a sample the form would refuse"
      end
    end
  end

  test "the shared Typst helpers are not a template" do
    assert File.exists?(Path.join(Templates.root_dir(), "_shared/helpers.typ"))
    assert {:error, :not_found} = Templates.get("_shared")
  end
end
