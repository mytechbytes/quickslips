defmodule QuickSlips.Templates.ItemsTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Templates
  alias QuickSlips.Templates.Items
  alias QuickSlips.Templates.Validator

  @schema %{
    "fields" => [
      %{
        "key" => "items",
        "type" => "items",
        "required" => true,
        "max_rows" => 3,
        "name_max_length" => 10,
        "legacy" => %{"name" => "item", "qty" => "qty", "rate" => "price", "count" => 3}
      }
    ]
  }

  defp row(name, qty, rate), do: %{"name" => name, "qty" => qty, "rate" => rate}

  describe "the items field of the validator" do
    test "keeps the rows, trimmed, and leaves out a row with nothing in it" do
      data = %{
        "items" => [
          row(" Rice ", 2, 40),
          %{"name" => "", "qty" => "", "rate" => nil},
          row("Dal", 1.5, 0)
        ]
      }

      assert {:ok,
              %{
                "items" => [
                  %{"name" => "Rice", "qty" => 2, "rate" => 40},
                  %{"name" => "Dal", "qty" => 1.5, "rate" => 0}
                ]
              }} =
               Validator.validate(@schema, data)
    end

    test "does not keep an amount that the client sent: it is quantity times rate" do
      data = %{"items" => [Map.put(row("Rice", 2, 40), "amount", 1)]}

      assert {:ok, %{"items" => [clean]}} = Validator.validate(@schema, data)
      assert Map.keys(clean) |> Enum.sort() == ["name", "qty", "rate"]
    end

    test "names a mistake after its cell, counting the rows that were sent from 0" do
      data = %{
        "items" => [row("Rice", 2, 40), %{"name" => "Dal", "qty" => 0}, row("Tea", "x", -1)]
      }

      assert {:error, {:validation, errors}} = Validator.validate(@schema, data)

      assert errors == %{
               "items.1.qty" => ["must be at least 0.01"],
               "items.1.rate" => ["is required"],
               "items.2.qty" => ["must be a number"],
               "items.2.rate" => ["must be at least 0"]
             }
    end

    test "a row with a quantity and no name needs a name, and a name is as long as the field says" do
      assert {:error, {:validation, %{"items.0.name" => ["is required"]}}} =
               Validator.validate(@schema, %{"items" => [%{"qty" => 1, "rate" => 1}]})

      assert {:error, {:validation, %{"items.0.name" => ["must be at most 10 characters"]}}} =
               Validator.validate(@schema, %{"items" => [row("12345678901", 1, 1)]})
    end

    test "needs a row when the field is required, and not when it is not" do
      for items <- [nil, [], [%{}], [%{"name" => ""}]] do
        assert {:error, {:validation, %{"items" => ["is required"]}}} =
                 Validator.validate(@schema, %{"items" => items})
      end

      optional = put_in(@schema, ["fields", Access.at(0), "required"], false)
      assert {:ok, clean} = Validator.validate(optional, %{"items" => []})
      assert clean == %{}
    end

    test "has a limit on the number of rows, and wants a list of objects" do
      too_many = for n <- 1..4, do: row("r#{n}", 1, 1)

      assert {:error, {:validation, %{"items" => ["must have at most 3 rows"]}}} =
               Validator.validate(@schema, %{"items" => too_many})

      assert {:error, {:validation, %{"items" => ["must be a list"]}}} =
               Validator.validate(@schema, %{"items" => "rice"})

      assert {:error, {:validation, %{"items.0" => ["must be an object"]}}} =
               Validator.validate(@schema, %{"items" => ["rice"]})
    end
  end

  describe "a table with a code, a billing type and a discount" do
    @parts %{
      "fields" => [
        %{
          "key" => "parts",
          "type" => "items",
          "cells" => ["code", "name", "billing", "qty", "rate", "discount"],
          "billing_options" => ["PAID", "Warranty", "Insurance"],
          "code_max_length" => 8
        },
        %{
          "key" => "labour",
          "type" => "items",
          "cells" => ["code", "name", "billing", "rate", "discount"],
          "billing_options" => ["PAID", "Warranty"]
        }
      ]
    }

    test "keeps every cell it has, and the labour has no quantity" do
      data = %{
        "parts" => [
          %{
            "code" => " A1 ",
            "name" => "Filter",
            "billing" => "Warranty",
            "qty" => 2,
            "rate" => 10,
            "discount" => 12.5
          }
        ],
        "labour" => [%{"name" => "Service", "billing" => "PAID", "rate" => 100, "qty" => 5}]
      }

      assert {:ok, clean} = Validator.validate(@parts, data)

      assert clean["parts"] == [
               %{
                 "code" => "A1",
                 "name" => "Filter",
                 "billing" => "Warranty",
                 "qty" => 2,
                 "rate" => 10,
                 "discount" => 12.5
               }
             ]

      assert clean["labour"] == [%{"name" => "Service", "billing" => "PAID", "rate" => 100}]
    end

    test "a row with only the billing type, which a form has from the start, is left out" do
      data = %{"parts" => [%{"billing" => "PAID", "name" => "", "qty" => ""}], "labour" => []}

      assert {:ok, clean} = Validator.validate(@parts, data)
      assert clean == %{}
    end

    test "checks the billing type, the discount, the length of the code and what a row needs" do
      data = %{
        "parts" => [
          %{"name" => "Filter", "qty" => 1, "rate" => 5, "billing" => "Free"},
          %{"name" => "Pad", "qty" => 1, "rate" => 5, "discount" => 101},
          %{"name" => "Oil", "qty" => 1, "rate" => 5, "discount" => -1},
          %{"name" => "Lamp", "qty" => 1, "rate" => 5, "code" => "123456789"},
          %{"code" => "X1"}
        ]
      }

      assert {:error, {:validation, errors}} = Validator.validate(@parts, data)

      assert errors == %{
               "parts.0.billing" => ["must be one of: PAID, Warranty, Insurance"],
               "parts.1.discount" => ["must be at most 100"],
               "parts.2.discount" => ["must be at least 0"],
               "parts.3.code" => ["must be at most 8 characters"],
               "parts.4.name" => ["is required"],
               "parts.4.qty" => ["is required"],
               "parts.4.rate" => ["is required"]
             }
    end

    test "a table can have a tax rate for each line, 0 to 100" do
      schema = %{
        "fields" => [
          %{"key" => "lines", "type" => "items", "cells" => ["name", "rate", "discount", "tax"]}
        ]
      }

      good = %{"lines" => [%{"name" => "Dosa", "rate" => 240, "discount" => 10, "tax" => 5}]}

      assert {:ok, %{"lines" => [%{"tax" => 5, "discount" => 10}]}} =
               Validator.validate(schema, good)

      bad = %{"lines" => [%{"name" => "Dosa", "rate" => 240, "tax" => 101}]}

      assert {:error, {:validation, %{"lines.0.tax" => ["must be at most 100"]}}} =
               Validator.validate(schema, bad)
    end

    test "a table of goods has short text cells: HSN, manufacturer, batch, expiry and schedule" do
      schema = %{
        "fields" => [
          %{
            "key" => "meds",
            "type" => "items",
            "cell_max_length" => 8,
            "cells" => ["name", "hsn", "mfr", "batch", "expiry", "schedule", "qty", "rate", "tax"]
          }
        ]
      }

      row = %{
        "name" => "Paracetamol",
        "hsn" => " 3004 ",
        "mfr" => "Alpha",
        "batch" => "PCM2407",
        "expiry" => "08/27",
        "schedule" => "H",
        "qty" => 2,
        "rate" => 30,
        "tax" => 5
      }

      assert {:ok, %{"meds" => [clean]}} = Validator.validate(schema, %{"meds" => [row]})
      assert clean["hsn"] == "3004" and clean["batch"] == "PCM2407" and clean["schedule"] == "H"

      assert {:error, {:validation, %{"meds.0.batch" => ["must be at most 8 characters"]}}} =
               Validator.validate(schema, %{"meds" => [%{row | "batch" => "123456789"}]})

      # a row that has none of them still passes; they are optional
      bare = %{"name" => "Gauze", "qty" => 1, "rate" => 5}

      assert {:ok, %{"meds" => [%{"name" => "Gauze"}]}} =
               Validator.validate(schema, %{"meds" => [bare]})
    end

    test "the billing types are named in the language of the page and of the document" do
      {:ok, schema} = Templates.get("maintenance-bill", QuickSlips.Locales.fetch!("es-es"))
      parts = Enum.find(schema["fields"], &(&1["key"] == "parts"))

      assert parts["option_labels"] == %{
               "PAID" => "Pagado",
               "Warranty" => "Garantía",
               "Insurance" => "Seguro"
             }

      assert parts["columns"]["code"] == "N.º de pieza"

      text = Templates.print_text("maintenance-bill", QuickSlips.Locales.fetch!("es-es"))
      assert text["options"]["parts"]["Warranty"] == "Garantía"
      assert text["options"]["labour"]["Insurance"] == "Seguro"
    end
  end

  describe "upgrade/2" do
    test "makes the rows of the numbered fields of an old document" do
      old = %{
        "store" => "S",
        "item_1" => "Rice",
        "qty_1" => 2,
        "price_1" => 40,
        "item_2" => "Dal",
        "qty_2" => 1,
        "item_3" => ""
      }

      assert Items.upgrade(@schema, old) ==
               %{"store" => "S", "items" => [row("Rice", 2, 40), row("Dal", 1, 0)]}
    end

    test "a quantity that is missing is 1, and a rate that is missing is 0" do
      assert %{"items" => [%{"qty" => 1, "rate" => 0}]} =
               Items.upgrade(@schema, %{"item_1" => "Rice"})
    end

    test "leaves new data, and data with nothing to upgrade, alone" do
      new = %{"items" => [row("Rice", 1, 1)], "item_1" => "ignored"}
      assert Items.upgrade(@schema, new) == new
      assert Items.upgrade(@schema, %{"store" => "S"}) == %{"store" => "S"}
      assert Items.upgrade(%{"fields" => []}, %{"item_1" => "x"}) == %{"item_1" => "x"}
    end
  end

  describe "the bills that have a table" do
    test "grocery, restaurant and invoice have one, which the form is told about" do
      for slug <- ["grocery-bill", "restaurant-bill", "service-invoice"] do
        {:ok, schema} = Templates.get(slug)

        assert %{"columns" => %{"name" => _, "qty" => _, "rate" => rate}, "max_rows" => 30} =
                 Enum.find(schema["fields"], &(&1["type"] == "items"))

        assert rate =~ "{currency}"
      end
    end

    test "an old sample, upgraded, is valid for each of them" do
      old = %{
        "grocery-bill" => %{
          "store_name" => "S",
          "bill_number" => "1",
          "date" => "2026-10-18",
          "item_1" => "Rice",
          "qty_1" => 1,
          "price_1" => 64,
          "payment_mode" => "Cash"
        },
        "restaurant-bill" => %{
          "restaurant_name" => "R",
          "bill_number" => "1",
          "date" => "2026-10-18",
          "item_1" => "Dosa",
          "qty_1" => 2,
          "price_1" => 120,
          "payment_mode" => "UPI"
        },
        "service-invoice" => %{
          "seller_name" => "P",
          "invoice_number" => "1",
          "invoice_date" => "2026-10-18",
          "client_name" => "C",
          "service_1" => "Work",
          "qty_1" => 1,
          "rate_1" => 500
        }
      }

      for {slug, data} <- old do
        {:ok, schema} = Templates.get(slug)

        assert {:ok, %{"items" => [%{"name" => _}]}} =
                 Validator.validate(schema, Items.upgrade(schema, data))
      end
    end
  end
end
