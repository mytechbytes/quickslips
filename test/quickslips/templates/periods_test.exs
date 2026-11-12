defmodule QuickSlips.Templates.PeriodsTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Templates.Items
  alias QuickSlips.Templates.Validator

  @schema %{
    "fields" => [
      %{
        "key" => "periods",
        "type" => "periods",
        "required" => true,
        "options" => ["Monthly", "Quarterly", "Half-yearly", "Yearly"]
      }
    ]
  }

  defp check(value), do: Validator.validate(@schema, %{"periods" => value})

  test "monthly takes from one to twelve months and one date for each, sorted and without repeats" do
    assert {:ok, %{"periods" => clean}} =
             check(%{
               "bill_by" => "Monthly",
               "months" => ["2026-10", "2026-09", "2026-09"],
               "dates" => ["2026-09-30"]
             })

    assert clean == %{
             "bill_by" => "Monthly",
             "months" => ["2026-09", "2026-10"],
             "dates" => ["2026-09-30", ""]
           }
  end

  test "a field with a number column keeps one number for each receipt, and one without drops them" do
    schema = put_in(@schema, ["fields", Access.at(0), "numbers"], true)
    value = %{"bill_by" => "Monthly", "months" => ["2026-09", "2026-10"], "numbers" => [" AB098 "]}

    assert {:ok, %{"periods" => %{"numbers" => ["AB098", ""]}}} =
             Validator.validate(schema, %{"periods" => value})

    assert {:ok, %{"periods" => clean}} = check(value)
    refute Map.has_key?(clean, "numbers")
  end

  test "the dates are optional: a receipt with no date keeps an empty one" do
    assert {:ok, %{"periods" => %{"dates" => [""]}}} =
             check(%{"bill_by" => "Monthly", "months" => ["2026-09"]})
  end

  test "no month, more than twelve months and a month that is not one are turned down" do
    assert {:error, _} = check(%{"bill_by" => "Monthly", "months" => []})

    thirteen = for n <- 1..13, do: "2025-#{String.pad_leading("#{rem(n - 1, 12) + 1}", 2, "0")}"

    assert {:error, _} =
             check(%{"bill_by" => "Monthly", "months" => Enum.uniq(thirteen) ++ ["2026-01"]})

    assert {:error, _} = check(%{"bill_by" => "Monthly", "months" => ["2026-13"]})
  end

  test "quarterly, half-yearly and yearly take the start month of each period, and a date for each" do
    assert {:ok, %{"periods" => clean}} =
             check(%{
               "bill_by" => "Quarterly",
               "months" => ["2026-07", "2026-04"],
               "dates" => ["2026-06-30", "2026-09-30", "2026-12-31"]
             })

    assert clean["months"] == ["2026-04", "2026-07"]
    assert clean["dates"] == ["2026-06-30", "2026-09-30"]

    assert {:ok, _} = check(%{"bill_by" => "Half-yearly", "months" => ["2026-04", "2026-10"]})
    assert {:ok, _} = check(%{"bill_by" => "Yearly", "months" => ["2026-04"]})
  end

  test "more periods than fit in twelve months, or spread over more than a year, are turned down" do
    assert {:ok, _} =
             check(%{"bill_by" => "Yearly", "months" => ["2024-04", "2025-04", "2026-04"]})

    assert {:error, _} =
             check(%{"bill_by" => "Yearly", "months" => for(y <- 2010..2020, do: "#{y}-04")})

    assert {:error, _} =
             check(%{"bill_by" => "Half-yearly", "months" => ["2026-01", "2026-07", "2027-01"]})

    assert {:error, _} =
             check(%{
               "bill_by" => "Quarterly",
               "months" => ["2026-01", "2026-04", "2026-07", "2026-10", "2027-01"]
             })

    assert {:error, _} = check(%{"bill_by" => "Quarterly", "months" => ["2026-01", "2027-06"]})
  end

  test "a way to bill that the bill does not offer, or a date that is not one, is turned down" do
    assert {:error, _} = check(%{"bill_by" => "Weekly", "months" => ["2026-04"]})

    assert {:error, _} =
             check(%{"bill_by" => "Monthly", "months" => ["2026-04"], "dates" => ["31/04/2026"]})
  end

  test "a document saved with the old month and date fields is upgraded to periods" do
    old = %{
      "month" => "2026-07",
      "from_date" => "2026-07-01",
      "to_date" => "2026-09-30",
      "bill_by" => "Quarterly"
    }

    assert %{"periods" => %{"bill_by" => by, "months" => months}} = Items.upgrade(@schema, old)
    assert by in ["Monthly", "Quarterly"]
    assert is_list(months) and months != []
    assert {:ok, _} = Validator.validate(@schema, Items.upgrade(@schema, old))
  end
end
