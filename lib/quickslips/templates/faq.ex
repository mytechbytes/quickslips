defmodule QuickSlips.Templates.Faq do
  @moduledoc """
  The questions and answers under a bill's page, in the language of its locale: `[%{"q" => _, "a" => _}]`.

  The sentences are `faq` in the shared text files (`priv/bill_templates/_shared/text/<language>.json`): the same
  questions for every bill, with what is true of this bill put in: its title, its designs, the details it needs, the
  tax of the country. A sentence has places to fill in, written `{title}`, `{designs}`, `{required}`, `{tax}`,
  `{rates}` and `{count}`; a place that nothing fills is left as it is, and a test looks for such leftovers.

  Some questions are asked only when they apply: the one about tax needs a bill that has a tax rate, the one about
  signatures a design with a place to sign.

  Chinese and Japanese write a list with another comma and no space between sentences, so the files say which
  `separator` goes between the parts of a list and which `joiner` between two sentences.
  """

  alias QuickSlips.Regions

  # A form with more required details than this lists the first ones, and says that there are others.
  @max_required 10

  @doc """
  The questions of a bill. `localized` is the bill as `Localizer.localize/4` made it (without its `faq`), `frames`
  the `faq` sentences of the language, `locale` the locale of the page. Nothing is asked when the language has no
  sentences (a test folder, a language not written yet).
  """
  def build(%{} = localized, %{} = frames, locale) do
    context = %{
      localized: localized,
      frames: frames,
      region: region(locale),
      joiner: frames["joiner"] || " ",
      separator: frames["separator"] || ", "
    }

    [
      how(context),
      required(context),
      tax(context),
      signature(context),
      plain(context, "free"),
      plain(context, "country"),
      plain(context, "official")
    ]
    |> Enum.reject(&is_nil/1)
  end

  def build(_localized, _frames, _locale), do: []

  # How to use the page, and which designs the bill has when it has more than one.
  defp how(%{frames: %{"how" => frame}} = context) do
    designs = context.localized["templates"]

    answer =
      if length(designs) > 1, do: [frame["a"], frame["designs"]], else: [frame["a"]]

    vars =
      Map.merge(base_vars(context), %{
        "count" => length(designs),
        "designs" => Enum.map_join(designs, context.separator, & &1["name"])
      })

    item(frame["q"], Enum.join(answer, context.joiner), vars)
  end

  defp how(_context), do: nil

  # The details the form asks for, as it names them. Many bills ask for a lot, and a list that long is no answer.
  defp required(%{frames: %{"required" => frame}} = context) do
    labels =
      context.localized["fields"]
      |> Enum.filter(& &1["required"])
      |> Enum.map(&label(&1, context.region))
      |> Enum.reject(&(&1 in [nil, ""]))
      |> Enum.uniq()

    case labels do
      [] ->
        nil

      _ ->
        {shown, answer} =
          if length(labels) > @max_required,
            do: {Enum.take(labels, @max_required), frame["a_more"]},
            else: {labels, frame["a"]}

        vars = Map.put(base_vars(context), "required", Enum.join(shown, context.separator))
        item(frame["q"], answer, vars)
    end
  end

  defp required(_context), do: nil

  # What the country does with tax on this bill: the rates it offers (or none: the visitor types one), and whether the
  # prices already hold the tax or the tax is added to them.
  defp tax(%{frames: %{"tax" => frame}} = context) do
    if Enum.any?(context.localized["fields"], &(&1["type"] == "tax_rate")) do
      rates = get_in(context.region, ["tax", "rates"]) || []
      choice = if rates == [], do: frame["typed"], else: frame["rates"]

      mode =
        if context.localized["tax_mode"] == "included",
          do: frame["included"],
          else: frame["added"]

      vars =
        Map.put(base_vars(context), "rates", Enum.map_join(rates, context.separator, &"#{&1}%"))

      item(frame["q"], Enum.join([choice, mode], context.joiner), vars)
    end
  end

  defp tax(_context), do: nil

  defp signature(%{frames: %{"signature" => frame}} = context) do
    if Enum.any?(context.localized["templates"], &(&1["signature"] == true)),
      do: item(frame["q"], frame["a"], base_vars(context))
  end

  defp signature(_context), do: nil

  # A question that every bill has, with the same answer.
  defp plain(context, key) do
    case context.frames[key] do
      %{"q" => question, "a" => answer} -> item(question, answer, base_vars(context))
      _no_such_question -> nil
    end
  end

  defp base_vars(context) do
    %{
      "title" => context.localized["title"],
      "name" => context.localized["name"],
      "tax" => get_in(context.region, ["tax", "name"]) || ""
    }
  end

  defp item(question, answer, vars), do: %{"q" => fill(question, vars), "a" => fill(answer, vars)}

  defp fill(text, vars) do
    Regex.replace(~r/\{(\w+)\}/, text, fn whole, key ->
      case Map.fetch(vars, key) do
        {:ok, value} -> to_string(value)
        :error -> whole
      end
    end)
  end

  # A label as the form shows it, with the names the country gives filled in: "{tax} (%)" is "GST (%)".
  defp label(%{"label" => label}, region) when is_binary(label) do
    label
    |> String.replace("{currency}", get_in(region, ["currency", "symbol"]) || "")
    |> String.replace("{tax_id}", get_in(region, ["tax", "id", "label"]) || "")
    |> String.replace("{tax}", get_in(region, ["tax", "name"]) || "")
    |> String.replace(~r/\s*\(\s*\)/, "")
    |> String.trim()
  end

  defp label(_field, _region), do: nil

  defp region(locale) do
    case Regions.build(locale.country, nil, locale.language) do
      {:ok, region} -> region
      {:error, _reason} -> %{}
    end
  end
end
