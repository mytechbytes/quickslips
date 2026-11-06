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
