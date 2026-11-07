defmodule QuickSlips.Render.AmountWordsTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Locales
  alias QuickSlips.Regions
  alias QuickSlips.Templates

  # Runs the Typst CLI, like the helper tests.
  @moduletag :typst
  @moduletag :tmp_dir

  # `amount-words` of `_shared/helpers.typ` for each amount, in the words and the region of `locale_code`. The
  # words come back through `typst eval`, so the test reads the exact text.
  defp say(dir, locale_code, amounts, currency \\ nil) do
    locale = Locales.fetch!(locale_code)
    {:ok, region} = Regions.build(locale.country, currency, locale.language)
    File.cp_r!(Path.join(Templates.root_dir(), "_shared"), Path.join(dir, "_shared"))
    File.write!(Path.join(dir, "region.json"), Jason.encode!(region))

    File.write!(
      Path.join(dir, "text.json"),
      Jason.encode!(Templates.print_text("fuel-bill", locale))
    )

    main = Path.join(dir, "main.typ")
    calls = Enum.map_join(amounts, ", ", &"amount-words(#{&1})")

    File.write!(main, """
    #import "_shared/helpers.typ": *
    #metadata((#{calls},)) <out>
    """)

    {out, 0} =
      System.cmd(
        System.find_executable("typst"),
        ["eval", "query(<out>).first().value", "--in", main, "--root", dir] ++
          ["--font-path", Application.app_dir(:quickslips, "priv/fonts"), "--ignore-system-fonts"],
        stderr_to_stdout: true
      )

    out |> Jason.decode!() |> then(&Enum.zip(amounts, &1)) |> Map.new()
  end

  defp assert_words(dir, locale_code, expected) do
    said = say(dir, locale_code, Map.keys(expected))

    for {amount, words} <- expected do
      assert said[amount] == words, "#{locale_code} #{amount}"
    end
  end

  test "English in India counts in lakhs and crores", %{tmp_dir: dir} do
    assert_words(dir, "en-in", %{
      0 => "Zero rupees only",
      1 => "One rupee only",
      21.5 => "Twenty-one rupees and fifty paise only",
      1050 => "One thousand and fifty rupees only",
      100_000 => "One lakh rupees only",
      12_345_678 =>
        "One crore twenty-three lakh forty-five thousand six hundred and seventy-eight rupees only",
      1234.56 => "One thousand two hundred and thirty-four rupees and fifty-six paise only"
    })
  end

  test "English in the United States and Britain differ in the hundreds and the money", %{
    tmp_dir: dir
  } do
    assert_words(dir, "en-us", %{
      1 => "One dollar only",
      101.01 => "One hundred one dollars and one cent only",
      2_500_000.5 => "Two million five hundred thousand dollars and fifty cents only"
    })

    assert_words(dir, "en-gb", %{
      1.01 => "One pound and one penny only",
      1234.5 => "One thousand two hundred and thirty-four pounds and fifty pence only"
    })
  end

  test "Hindi", %{tmp_dir: dir} do
    assert_words(dir, "hi-in", %{
      1 => "एक रुपया मात्र",
      123 => "एक सौ तेईस रुपये मात्र",
      21.5 => "इक्कीस रुपये और पचास पैसे मात्र",
      1234.56 => "एक हज़ार दो सौ चौंतीस रुपये और छप्पन पैसे मात्र",
      12_345_678 => "एक करोड़ तेईस लाख पैंतालीस हज़ार छह सौ अठहत्तर रुपये मात्र"
    })
  end

  test "Spanish: un, una and veintiún before a noun, and de for whole millions", %{tmp_dir: dir} do
    assert_words(dir, "es-es", %{
      0 => "Cero euros",
      1 => "Un euro",
      21 => "Veintiún euros",
      101 => "Ciento un euros",
      1000 => "Mil euros",
      21_000 => "Veintiún mil euros",
      1234.56 => "Mil doscientos treinta y cuatro euros con cincuenta y seis céntimos",
      1_000_000 => "Un millón de euros",
      2_000_000 => "Dos millones de euros",
      1_001_001 => "Un millón mil un euros",
      1_000_000_000 => "Mil millones de euros"
    })
  end

  test "Spanish: a feminine currency makes the one and the hundreds feminine", %{tmp_dir: dir} do
    said = say(dir, "es-es", [1, 200, 21], "GBP")

    assert said == %{1 => "Una libra", 200 => "Doscientas libras", 21 => "Veintiuna libras"}
  end

  test "German: one word up to a million, spaces above", %{tmp_dir: dir} do
    assert_words(dir, "de-de", %{
      0 => "Null Euro",
      1 => "Ein Euro",
      21 => "Einundzwanzig Euro",
      101 => "Einhunderteins Euro",
      1000 => "Eintausend Euro",
      1234.56 => "Eintausendzweihundertvierunddreißig Euro und sechsundfünfzig Cent",
      1_000_000 => "Eine Million Euro",
      2_000_000 => "Zwei Millionen Euro",
      1_234_567.89 =>
        "Eine Million zweihundertvierunddreißigtausendfünfhundertsiebenundsechzig Euro und neunundachtzig Cent"
    })
  end

  test "French: soixante-dix, quatre-vingts, and the s of cent", %{tmp_dir: dir} do
    assert_words(dir, "fr-fr", %{
      0 => "Zéro euro",
      1 => "Un euro",
      21 => "Vingt et un euros",
      71 => "Soixante et onze euros",
      80 => "Quatre-vingts euros",
      81 => "Quatre-vingt-un euros",
      91 => "Quatre-vingt-onze euros",
      200 => "Deux cents euros",
      201 => "Deux cent un euros",
      80_000 => "Quatre-vingt mille euros",
      200_000 => "Deux cent mille euros",
      1_000_000 => "Un million d'euros",
      1234.56 => "Mille deux cent trente-quatre euros et cinquante-six centimes"
    })
  end

  test "French: the feminine one, and de before a consonant", %{tmp_dir: dir} do
    said = say(dir, "fr-fr", [1, 21, 1_000_000], "GBP")

    assert said == %{
             1 => "Une livre sterling",
             21 => "Vingt et une livres sterling",
             1_000_000 => "Un million de livres sterling"
           }
  end

  test "Italian: one word up to a million, ventun, centotto, tré, di", %{tmp_dir: dir} do
    assert_words(dir, "it-it", %{
      0 => "Zero euro",
      1 => "Un euro",
      21 => "Ventun euro",
      23 => "Ventitré euro",
      101 => "Centouno euro",
      108 => "Centotto euro",
      1000 => "Mille euro",
      21_000 => "Ventunomila euro",
      1234.56 => "Milleduecentotrentaquattro euro e cinquantasei centesimi",
      1_000_000 => "Un milione di euro",
      1_233_333.33 =>
        "Un milione duecentotrentatremilatrecentotrentatré euro e trentatré centesimi"
    })
  end

  test "Portuguese: e before the last part, cem and cento, de for whole millions", %{tmp_dir: dir} do
    assert_words(dir, "pt-br", %{
      0 => "Zero reais",
      1 => "Um real",
      2 => "Dois reais",
      21 => "Vinte e um reais",
      100 => "Cem reais",
      101 => "Cento e um reais",
      1100 => "Mil e cem reais",
      1050 => "Mil e cinquenta reais",
      1234.56 => "Mil duzentos e trinta e quatro reais e cinquenta e seis centavos",
      1_500_000 => "Um milhão e quinhentos mil reais",
      2_000_000 => "Dois milhões de reais",
      1_000_000_000 => "Um bilhão de reais"
    })
  end

  test "Chinese: capital numerals, 零 for a skipped place, 整 when there is no small change", %{
    tmp_dir: dir
  } do
    assert_words(dir, "zh-cn", %{
      0 => "人民币零元整",
      100 => "人民币壹佰元整",
      1050 => "人民币壹仟零伍拾元整",
      10_005 => "人民币壹万零伍元整",
      120_000 => "人民币壹拾贰万元整",
      100_005_000 => "人民币壹亿零伍仟元整",
      1234.56 => "人民币壹仟贰佰叁拾肆元伍角陆分",
      0.45 => "人民币肆角伍分",
      1.05 => "人民币壹元零伍分"
    })
  end

  test "Japanese: 金, formal numerals, 円也", %{tmp_dir: dir} do
    assert_words(dir, "ja-jp", %{
      0 => "金零円也",
      12_345 => "金壱万弐千参百四拾五円也",
      100_000_000 => "金壱億円也",
      10_005 => "金壱万五円也"
    })
  end

  test "the largest number is a trillion less one; bigger and negative amounts have no words", %{
    tmp_dir: dir
  } do
    said = say(dir, "en-us", [999_999_999_999, 1_000_000_000_000, -5])

    assert said[999_999_999_999] =~ "Nine hundred ninety-nine billion"
    assert said[1_000_000_000_000] == nil
    assert said[-5] == nil
  end

  test "every live language has words for every currency of the regions", %{tmp_dir: dir} do
    for locale <- Locales.live(), currency <- ~w(INR EUR USD CNY JPY GBP BRL CAD) do
      said = say(dir, locale.code, [1, 2.5], currency)

      assert is_binary(said[1]), "#{locale.code} #{currency}"
      assert is_binary(said[2.5]), "#{locale.code} #{currency}"
    end
  end
end
