defmodule QuickSlips.Templates.FaqTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Locales
  alias QuickSlips.Templates.Faq

  @frames %{
    "separator" => ", ",
    "joiner" => " ",
    "how" => %{
      "q" => "How do I use the {title}?",
      "a" => "Fill in the form.",
      "designs" => "Choose one of the {count} designs: {designs}."
    },
    "required" => %{
      "q" => "Which details?",
      "a" => "You need: {required}.",
      "a_more" => "Among others: {required}."
    },
    "tax" => %{
      "q" => "Does it work out the tax ({tax})?",
      "rates" => "Choose a rate ({rates}).",
      "typed" => "Type the rate.",
      "added" => "It is added.",
      "included" => "It is included."
    },
    "signature" => %{"q" => "Signature?", "a" => "Yes, log in."},
    "free" => %{"q" => "Free?", "a" => "Yes."},
    "country" => %{"q" => "Another country?", "a" => "Yes."},
    "official" => %{"q" => "Official?", "a" => "No."}
  }

  defp field(key, label, extra \\ %{}) do
    Map.merge(%{"key" => key, "label" => label, "type" => "text", "required" => true}, extra)
  end

  defp bill(extra \\ %{}) do
    Map.merge(
      %{
        "title" => "Fuel Bill Generator",
        "name" => "Fuel Bill",
        "tax_mode" => nil,
        "templates" => [%{"id" => "t1", "name" => "Receipt"}],
        "fields" => [field("station", "Station name")]
      },
      extra
    )
  end

  defp build(localized, code \\ "en-in", frames \\ @frames) do
    Faq.build(localized, frames, Locales.fetch!(code))
  end

  defp questions(faq), do: Enum.map(faq, & &1["q"])
  defp answer(faq, question), do: Enum.find_value(faq, &(&1["q"] == question && &1["a"]))

  test "every bill is asked how to use it, what it needs, whether it is free, other countries, and whether it is official" do
    assert questions(build(bill())) == [
             "How do I use the Fuel Bill Generator?",
             "Which details?",
             "Free?",
             "Another country?",
             "Official?"
           ]
  end

  test "has nothing to ask when the language has no sentences" do
    assert build(bill(), "en-in", nil) == []
    assert build(bill(), "en-in", %{}) == []
  end

  describe "how" do
    test "names the designs only when there are several" do
      one = build(bill())
      assert answer(one, "How do I use the Fuel Bill Generator?") == "Fill in the form."

      designs =
        for {id, name} <- [{"t1", "Receipt"}, {"t2", "Slip"}, {"t3", "Thermal"}],
            do: %{"id" => id, "name" => name}

      many = build(bill(%{"templates" => designs}))

      assert answer(many, "How do I use the Fuel Bill Generator?") ==
               "Fill in the form. Choose one of the 3 designs: Receipt, Slip, Thermal."
    end
  end

  describe "required" do
    test "lists the details the form asks for, as it names them, and leaves out the optional ones" do
      fields = [
        field("rate", "Rate ({currency})"),
        field("tax", "{tax} (%)"),
        field("gstin", "{tax_id}"),
        field("note", "Note (optional)", %{"required" => false}),
        field("blank", "{currency}")
      ]

      faq = build(bill(%{"fields" => fields}))

      # India: the rupee sign, GST and the GSTIN take the place of the words in braces.
      assert answer(faq, "Which details?") == "You need: Rate (₹), GST (%), GSTIN, ₹."
    end

    test "says 'among others' and lists ten when the form asks for more" do
      fields = for n <- 1..12, do: field("f#{n}", "Detail #{n}")
      faq = build(bill(%{"fields" => fields}))

      assert answer(faq, "Which details?") ==
               "Among others: " <> Enum.map_join(1..10, ", ", &"Detail #{&1}") <> "."
    end

    test "asks nothing when no detail is required" do
      faq = build(bill(%{"fields" => [field("a", "A", %{"required" => false})]}))

      refute "Which details?" in questions(faq)
    end

    test "says each detail once" do
      faq = build(bill(%{"fields" => [field("a", "Name"), field("b", "Name")]}))

      assert answer(faq, "Which details?") == "You need: Name."
    end
  end

  describe "tax" do
    defp tax_field, do: field("rate", "Tax rate", %{"type" => "tax_rate"})

    test "is asked only when the bill has a tax rate" do
      refute "Does it work out the tax (GST)?" in questions(build(bill()))

      assert "Does it work out the tax (GST)?" in questions(
               build(bill(%{"fields" => [tax_field()]}))
             )
    end

    test "offers the rates of the country, and says the tax is added" do
      faq = build(bill(%{"fields" => [tax_field()], "tax_mode" => "added"}))

      assert answer(faq, "Does it work out the tax (GST)?") ==
               "Choose a rate (0%, 5%, 18%, 40%). It is added."
    end

    test "says the price holds the tax where the country does it that way" do
      faq = build(bill(%{"fields" => [tax_field()], "tax_mode" => "included"}), "es-es")

      assert answer(faq, "Does it work out the tax (IVA)?") ==
               "Choose a rate (0%, 4%, 10%, 21%). It is included."
    end

    test "asks the visitor to type the rate in a country that has no standard rates" do
      faq = build(bill(%{"fields" => [tax_field()]}), "en-us")

      assert [answer] =
               for(%{"q" => "Does it work out the tax (" <> _, "a" => a} <- faq, do: a)

      assert answer == "Type the rate. It is added."
    end
  end

  describe "signature" do
    test "is asked only when a design has a place to sign" do
      refute "Signature?" in questions(build(bill()))

      designs = [
        %{"id" => "t1", "name" => "A", "signature" => false},
        %{"id" => "t2", "name" => "B", "signature" => true}
      ]

      assert "Signature?" in questions(build(bill(%{"templates" => designs})))
    end
  end

  test "a language that writes lists and sentences differently says how" do
    frames =
      @frames
      |> Map.merge(%{"separator" => "、", "joiner" => ""})

    designs = [%{"id" => "t1", "name" => "甲"}, %{"id" => "t2", "name" => "乙"}]

    faq =
      build(
        bill(%{"templates" => designs, "fields" => [field("a", "一"), field("b", "二")]}),
        "zh-cn",
        frames
      )

    assert answer(faq, "How do I use the Fuel Bill Generator?") ==
             "Fill in the form.Choose one of the 2 designs: 甲、乙."

    assert answer(faq, "Which details?") == "You need: 一、二."
  end

  test "a place that nothing fills is left as it is, so a test can find it" do
    frames = put_in(@frames, ["free", "a"], "Yes, {nothing_fills_this}.")

    assert answer(build(bill(), "en-in", frames), "Free?") == "Yes, {nothing_fills_this}."
  end
end
