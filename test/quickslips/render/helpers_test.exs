defmodule QuickSlips.Render.HelpersTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Locales
  alias QuickSlips.Regions
  alias QuickSlips.Templates

  # Runs the Typst CLI, like the renderer tests.
  @moduletag :typst
  @moduletag :tmp_dir

  # What the helpers of `_shared/helpers.typ` make of the region and the words they are given. The values come
  # back through `typst eval`, so the test reads the exact text, not a picture of it.
  defp evaluate(dir, expression, region, locale_code \\ "en-in", extra_text \\ %{}) do
    locale = Locales.fetch!(locale_code)
    File.cp_r!(Path.join(Templates.root_dir(), "_shared"), Path.join(dir, "_shared"))
    File.write!(Path.join(dir, "region.json"), Jason.encode!(region))

    File.write!(
      Path.join(dir, "text.json"),
      Jason.encode!(Map.merge(Templates.print_text("fuel-bill", locale), extra_text))
    )

    main = Path.join(dir, "main.typ")

    File.write!(main, """
    #import "_shared/helpers.typ": *
    #metadata(#{expression}) <out>
    """)

    typst = System.find_executable("typst")
    fonts = Application.app_dir(:quickslips, "priv/fonts")

    {out, 0} =
      System.cmd(
        typst,
        ["eval", "query(<out>).first().value", "--in", main, "--root", dir] ++
          ["--font-path", fonts, "--ignore-system-fonts"],
        stderr_to_stdout: true
      )

    Jason.decode!(out)
  end

  defp region(country, currency \\ nil), do: elem(Regions.build(country, currency), 1)

  # The region of a country that has no file yet: the United States as it will be written.
  defp us_region do
    %{
      "country" => "us",
      "currency" => %{"code" => "USD", "symbol" => "$", "decimals" => 2},
      "number" => %{"decimal" => ".", "group" => ",", "grouping" => "standard"},
      "money" => %{"position" => "before", "space" => false},
      "date" => %{"order" => "mdy", "separator" => "/"}
    }
  end

  @nbsp " "

  describe "money/1" do
    test "in India: the rupee sign, lakhs and crores, two decimals", %{tmp_dir: dir} do
      result =
        evaluate(
          dir,
          "(big: money(12345678.9), small: money(5), negative: money(-1234.5), noise: money(0.1 + 0.2))",
          region("in")
        )

      assert result == %{
               "big" => "₹#{@nbsp}1,23,45,678.90",
               "small" => "₹#{@nbsp}5.00",
               "negative" => "₹#{@nbsp}-1,234.50",
               "noise" => "₹#{@nbsp}0.30"
             }
    end

    test "in Spain: a dot for the thousands, a comma for the decimals, the sign after", %{
      tmp_dir: dir
    } do
      result =
        evaluate(
          dir,
          "(big: money(1234567.5), small: money(5), negative: money(-1234.5))",
          region("es")
        )

      assert result == %{
               "big" => "1.234.567,50#{@nbsp}€",
               "small" => "5,00#{@nbsp}€",
               "negative" => "-1.234,50#{@nbsp}€"
             }
    end

    test "a currency that is not the country's keeps the country's way of writing numbers", %{
      tmp_dir: dir
    } do
      assert evaluate(dir, "money(1234567.5)", region("in", "EUR")) == "€#{@nbsp}12,34,567.50"
    end

    test "with no space after the sign, and with a currency that has no decimals", %{tmp_dir: dir} do
      assert evaluate(dir, "money(1234567.5)", us_region()) == "$1,234,567.50"

      yen =
        put_in(us_region(), ["currency"], %{"code" => "JPY", "symbol" => "¥", "decimals" => 0})

      assert evaluate(dir, "money(1234567)", yen) == "¥1,234,567"
    end
  end

  describe "dates and numbers" do
    test "a date follows the order and the separator of the country", %{tmp_dir: dir} do
      assert evaluate(dir, ~s{fmt-date("2026-10-12")}, region("in")) == "12/10/2026"
      assert evaluate(dir, ~s{fmt-date("2026-10-12")}, region("es")) == "12/10/2026"
      assert evaluate(dir, ~s{fmt-date("2026-10-12")}, us_region()) == "10/12/2026"

      iso = put_in(us_region(), ["date"], %{"order" => "ymd", "separator" => "-"})
      assert evaluate(dir, ~s{fmt-date("2026-10-02")}, iso) == "2026-10-02"
    end

    test "a plain number takes the decimal mark of the country", %{tmp_dir: dir} do
      expression = "(half: fmt-number(28.5), whole: fmt-number(28), long: fmt-number(1.23456))"

      assert evaluate(dir, expression, region("in")) == %{
               "half" => "28.5",
               "whole" => "28",
               "long" => "1.235"
             }

      assert evaluate(dir, expression, region("es")) == %{
               "half" => "28,5",
               "whole" => "28",
               "long" => "1,235"
             }
    end
  end

  describe "words" do
    test "the month names come from the language, not from the country", %{tmp_dir: dir} do
      expression = ~s{month-label("2026-10")}

      assert evaluate(dir, expression, region("in"), "en-in") == "October 2026"
      assert evaluate(dir, expression, region("in"), "hi-in") == "अक्टूबर 2026"
      assert evaluate(dir, expression, region("es"), "es-es") == "octubre 2026"
    end

    test "an option shows its name in the language, and an unknown one shows as it is", %{
      tmp_dir: dir
    } do
      expression =
        ~s{(known: option-label("fuel_type", "Petrol"), unknown: option-label("fuel_type", "Coal"), field: option-label("nope", "Petrol"))}

      assert evaluate(dir, expression, region("in"), "hi-in") ==
               %{"known" => "पेट्रोल", "unknown" => "Coal", "field" => "Petrol"}

      assert evaluate(dir, expression, region("es"), "es-es")["known"] == "Gasolina"
    end

    test "the words a layout prints", %{tmp_dir: dir} do
      assert evaluate(dir, "t.total", region("in"), "en-in") == "Total"
      assert evaluate(dir, "t.total", region("in"), "hi-in") == "कुल"
      assert evaluate(dir, "t.total", region("es"), "es-es") == "Total"
    end
  end

  describe "tax and the money of other countries" do
    test "tax-split works out a price that holds the tax, and a tax that is added", %{
      tmp_dir: dir
    } do
      expression =
        "(a: tax-split(121, 21).tax, b: tax-split(100, 21).total, c: tax-split(121, 21).base)"

      for {mode, expected} <- [
            {"included", %{"a" => 21.0, "b" => 100.0, "c" => 100.0}},
            {"added", %{"a" => 25.41, "b" => 121.0, "c" => 121}}
          ] do
        result = evaluate(dir, expression, region("es"), "es-es", %{"tax_mode" => mode})
        assert_in_delta result["a"], expected["a"], 0.001
        assert_in_delta result["b"], expected["b"], 0.001
        assert_in_delta result["c"], expected["c"], 0.001
      end
    end

    test "money in Japan has no decimals, in France a narrow space, in Brazil a space after R$",
         %{tmp_dir: dir} do
      assert evaluate(dir, "money(1234567)", region("jp")) == "¥1,234,567"
      assert evaluate(dir, "money(1234.5)", region("fr")) == "1\u202f234,50\u00a0€"
      assert evaluate(dir, "money(1234.5)", region("br")) == "R$\u00a01.234,50"
      assert evaluate(dir, "money(1234.5)", region("de")) == "1.234,50\u00a0€"
      assert evaluate(dir, "money(1234.5)", region("gb")) == "£1,234.50"

      assert evaluate(dir, "money(1234.5)", elem(Regions.build("ca", nil, "fr"), 1)) ==
               "1\u00a0234,50\u00a0$"
    end

    test "dates in Japan and Canada run year first, in Germany with dots", %{tmp_dir: dir} do
      assert evaluate(dir, ~s{fmt-date("2026-10-12")}, region("jp")) == "2026/10/12"
      assert evaluate(dir, ~s{fmt-date("2026-10-12")}, region("ca")) == "2026-10-12"
      assert evaluate(dir, ~s{fmt-date("2026-10-12")}, region("de")) == "12.10.2026"
    end
  end
end
