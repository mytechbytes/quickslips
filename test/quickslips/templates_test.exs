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

  @categories ["Travel", "Home & utilities", "Health & learning", "Food & shopping", "Work"]

  test "the catalogue has fifteen templates in five categories" do
    templates = Templates.list()

    assert length(templates) == 15

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
        assert field["type"] in ["text", "textarea", "number", "date", "month", "select"]
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

  test "the shared Typst helpers are not a template" do
    assert File.exists?(Path.join(Templates.root_dir(), "_shared/helpers.typ"))
    assert {:error, :not_found} = Templates.get("_shared")
  end
end
