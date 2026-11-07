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
  alias QuickSlips.Regions

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
    mode = tax_mode(schema, locale.country)

    Map.merge(schema, %{
      "tax_mode" => mode,
      "locale" => locale.code,
      "language" => locale.language,
      "public_slug" => text["public_slug"] || schema["public_slug"] || schema["slug"],
      "title" => title,
      "name" => text["name"] || (title && String.replace_suffix(title, " Generator", "")),
      "summary" => with_tax(text["summary"] || schema["summary"], tax(locale)),
      "description" => with_tax(text["description"] || schema["description"], tax(locale)),
      "category_name" => category_name(schema, shared, locale),
      "languages" => schema["languages"] || ["en"],
      "templates" => Enum.map(schema["templates"], &localize_design(&1, text["designs"] || %{})),
      "fields" =>
        schema["fields"]
        |> Enum.filter(&in_country?(&1, locale.country))
        |> Enum.reject(&(&1["type"] == "tax_rate" and mode == "none"))
        |> Enum.map(&localize_field(&1, text["fields"] || %{}, tax(locale)))
    })
  end

  # `{tax}` in a summary or a description is what the country calls its tax: "GST", "IVA", "VAT".
  defp with_tax(nil, _tax), do: nil
  defp with_tax(text, tax), do: String.replace(text, "{tax}", tax["name"] || "tax")

  defp category_name(schema, shared, locale) do
    categories = merged(shared, locale)["categories"] || %{}
    Map.get(categories, schema["category"], schema["category"])
  end

  defp localize_design(design, names) do
    Map.put(design, "name", names[design["id"]] || design["name"] || design["id"])
  end

  # What a bill does with tax in a country, from the `"tax"` rule of its schema: `{"default": "added", "es": "included"}`.
  # `"none"`: no tax rate on the bill; `"added"`: the rate is added to the amount; `"included"`: the amount already
  # holds the tax and the bill shows how much. A schema with no rule keeps the rate field it has (`nil`).
  defp tax_mode(%{"tax" => %{} = rule}, country), do: rule[country] || rule["default"] || "none"
  defp tax_mode(_schema, _country), do: nil

  # A field with `"countries": ["in"]` (a registration number only India has) is only in the pages of those countries.
  defp in_country?(%{"countries" => countries}, country), do: country in countries
  defp in_country?(_field, _country), do: true

  defp tax(locale) do
    case Regions.build(locale.country, nil, locale.language) do
      {:ok, %{"tax" => %{} = tax}} -> tax
      _ -> %{}
    end
  end

  defp localize_field(field, texts, tax) do
    words = Map.get(texts, field["key"], %{})
    field = Map.put(field, "label", words["label"] || field["label"])

    case field do
      # The rates the country offers, and how its tax-registration number looks.
      %{"type" => "tax_rate"} ->
        Map.put(field, "rates", tax["rates"] || [])

      %{"type" => "tax_id"} ->
        Map.put_new(field, "pattern", get_in(tax, ["id", "pattern"]))

      %{"type" => "select", "options" => options} ->
        names = words["options"] || field["option_labels"] || %{}
        Map.put(field, "option_labels", Map.new(options, &{&1, names[&1] || &1}))

      # The heads of the columns of a table of items: `{"name": "Item", "qty": "Qty", "rate": "Price ({currency})"}`.
      %{"type" => "items"} ->
        Map.put(field, "columns", Map.merge(field["columns"] || %{}, words["columns"] || %{}))

      _ ->
        field
    end
  end

  @doc """
  What the Typst helpers read as `text.json` for a document in `locale`: the language, the names of the months,
  the words of the amount in words, the words the layout prints and the names of the options of the select
  fields. `localized` is the result of `localize/4`.
  """
  def print_text(localized, texts, shared, locale) do
    text = merged(texts, locale)
    words = merged(shared, locale)

    options =
      for %{"type" => "select", "key" => key, "option_labels" => labels} <- localized["fields"],
          into: %{},
          do: {key, labels}

    mode =
      localized["tax_mode"] ||
        if(Enum.any?(localized["fields"], &(&1["type"] == "tax_rate")), do: "added", else: "none")

    %{
      "lang" => locale.language,
      "fonts" => QuickSlips.Fonts.families(locale.language),
      "tax_mode" => mode,
      "months" => words["months"],
      "months_short" => words["months_short"],
      "in_words" => words["in_words"],
      "print" => text["print"] || %{},
      "options" => options
    }
  end

  @doc "The sample a form starts with: `sample.json`, with the words (and the numbers) of the language over it."
  def sample(base, texts, locale) do
    base
    |> adapt_to_country(Regions.example(locale.country))
    |> Map.merge(merged(texts, locale)["sample"] || %{})
  end

  # The sample of a template is written for India: an Indian address, a GSTIN, UPI. For another country the
  # addresses and the registration numbers are that country's examples, and cash is paid with. What a text file
  # says for its own language and country (`sample`) is laid over this.
  defp adapt_to_country(sample, nil), do: sample

  defp adapt_to_country(sample, example) do
    Map.new(sample, fn
      {key, _value} when key in ~w(gstin client_gstin seller_tax_id) ->
        {key, example["tax_id"]}

      {key, value} when is_binary(value) ->
        cond do
          String.ends_with?(key, "_address") -> {key, example["address"]}
          value == "UPI" -> {key, "Cash"}
          true -> {key, value}
        end

      other ->
        other
    end)
    |> Map.drop(~w(fssai_number landlord_pan))
  end

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
