defmodule QuickSlips.TemplatesTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Templates

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
end
