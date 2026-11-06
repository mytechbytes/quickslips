defmodule QuickSlips.Templates.Localizer do
  @moduledoc """
  Puts the words of a language into a template. These are plain functions on data the registry has read;
  nothing here touches the disk.

  A template folder holds the structure of a bill (`schema.json`) and its words in `text/<language>.json`
  (`en.json`, `hi.json`, and a locale like `es-mx.json` for what differs in one country). A `schema.json` of an
  older template may still hold its English words inline (`title`, `label`, ...): they are what the text files
  are laid over, so such a template needs no `text/` folder until it is translated.

  A text file looks like this (`{currency}` in a label is replaced by the sign of the document's currency in
  the browser):

      {
        "title": "Fuel Bill Generator", "name": "Fuel Bill", "public_slug": "fuel-bill-generator",
        "summary": "...", "description": "...",
        "designs": {"t1": "Classic"},
        "fields": {"fuel_type": {"label": "Fuel type", "options": {"Petrol": "Petrol"}}},
        "print": {"total": "Total"},      // the words the layout prints, as `t.total`
        "sample": {"station_name": "..."} // what the sample form starts with, over `sample.json`
      }

  Which file a word comes from is decided by `QuickSlips.Locales.chain/1`: `es-mx`, then `es`, then `en`.
  """

  alias QuickSlips.Locales

  @doc "The text files of a template (or the shared ones) as one map for `locale`: the most specific file wins."
  def merged(texts, locale) do
    locale
    |> Locales.chain()
    |> Enum.reverse()
    |> Enum.reduce(%{}, fn name, merged -> deep_merge(merged, Map.get(texts, name, %{})) end)
  end

  @doc """
  The schema of a template as a visitor of `locale` sees it: the title, the summary, the labels of the fields,
  the names of the options and of the designs are in their language. It keeps every key of the schema, so the
  validator and the renderer need not know whether a template has been translated.
  """
  def localize(schema, texts, shared, locale) do
    text = merged(texts, locale)
    title = text["title"] || schema["title"]

    Map.merge(schema, %{
      "locale" => locale.code,
      "language" => locale.language,
      "public_slug" => text["public_slug"] || schema["public_slug"] || schema["slug"],
      "title" => title,
      "name" => text["name"] || (title && String.replace_suffix(title, " Generator", "")),
      "summary" => text["summary"] || schema["summary"],
      "description" => text["description"] || schema["description"],
      "category_name" => category_name(schema, shared, locale),
      "languages" => schema["languages"] || ["en"],
      "templates" => Enum.map(schema["templates"], &localize_design(&1, text["designs"] || %{})),
      "fields" => Enum.map(schema["fields"], &localize_field(&1, text["fields"] || %{}))
    })
  end

  defp category_name(schema, shared, locale) do
    categories = merged(shared, locale)["categories"] || %{}
    Map.get(categories, schema["category"], schema["category"])
  end

  defp localize_design(design, names) do
    Map.put(design, "name", names[design["id"]] || design["name"] || design["id"])
  end

  defp localize_field(field, texts) do
    words = Map.get(texts, field["key"], %{})
    field = Map.put(field, "label", words["label"] || field["label"])

    case field do
      %{"type" => "select", "options" => options} ->
        names = words["options"] || field["option_labels"] || %{}
        Map.put(field, "option_labels", Map.new(options, &{&1, names[&1] || &1}))

      _ ->
        field
    end
  end

  @doc """
  What the Typst helpers read as `text.json` for a document in `locale`: the language, the names of the months,
  the words the layout prints and the names of the options of the select fields. `localized` is the result of
  `localize/4`.
  """
  def print_text(localized, texts, shared, locale) do
    text = merged(texts, locale)
    words = merged(shared, locale)

    options =
      for %{"type" => "select", "key" => key, "option_labels" => labels} <- localized["fields"],
          into: %{},
          do: {key, labels}

    %{
      "lang" => locale.language,
      "months" => words["months"],
      "months_short" => words["months_short"],
      "print" => text["print"] || %{},
      "options" => options
    }
  end

  @doc "The sample a form starts with: `sample.json`, with the words (and the numbers) of the language over it."
  def sample(base, texts, locale), do: Map.merge(base, merged(texts, locale)["sample"] || %{})

  @doc """
  The dotted names of the keys that `reference` has and `candidate` has not, like `["fields.rate.label"]`. It
  tells a translation what is still missing.
  """
  def missing(reference, candidate, path \\ [])

  def missing(%{} = reference, candidate, path) do
    candidate = if is_map(candidate), do: candidate, else: %{}

    Enum.flat_map(reference, fn {key, value} ->
      case candidate do
        %{^key => other} when is_map(value) -> missing(value, other, path ++ [key])
        %{^key => _other} -> []
        _ -> [Enum.join(path ++ [key], ".")]
      end
    end)
  end

  defp deep_merge(left, right) do
    Map.merge(left, right, fn
      _key, %{} = left, %{} = right -> deep_merge(left, right)
      _key, _left, right -> right
    end)
  end
end
