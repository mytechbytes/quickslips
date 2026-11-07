defmodule QuickSlips.Templates.ValidatorTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Templates
  alias QuickSlips.Templates.Validator

  setup do
    {:ok, schema} = Templates.get("fuel-bill")
    sample = "priv/bill_templates/fuel-bill/sample.json" |> File.read!() |> Jason.decode!()
    %{schema: schema, sample: sample}
  end

  test "the sample passes its own schema", %{schema: schema, sample: sample} do
    assert {:ok, _clean} = Validator.validate(schema, sample)
  end

  test "drops unknown keys", %{schema: schema, sample: sample} do
    {:ok, clean} = Validator.validate(schema, Map.put(sample, "evil", "x"))
    refute Map.has_key?(clean, "evil")
  end

  test "reports required, range and option errors", %{schema: schema, sample: sample} do
    bad =
      sample
      |> Map.delete("station_name")
      |> Map.put("quantity", 0)
      |> Map.put("fuel_type", "Coal")

    assert {:error, {:validation, errors}} = Validator.validate(schema, bad)
    assert errors["station_name"] == ["is required"]
    assert Map.has_key?(errors, "quantity")
    assert Map.has_key?(errors, "fuel_type")
  end

  test "a time is hours and minutes of a day", %{schema: schema, sample: sample} do
    for good <- ["00:00", "09:05", "23:59"] do
      assert {:ok, %{"time" => ^good}} = Validator.validate(schema, Map.put(sample, "time", good))
    end

    for bad <- ["24:00", "9:05", "10:60", "noon", 1025] do
      assert {:error, {:validation, %{"time" => ["must be a time like 14:30"]}}} =
               Validator.validate(schema, Map.put(sample, "time", bad))
    end

    {:ok, clean} = Validator.validate(schema, Map.put(sample, "time", ""))
    refute Map.has_key?(clean, "time")
  end
end
