defmodule QuickSlips.LocalesTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Locales

  # Every locale live and offered automatically, to test the guessing without the launch settings.
  @all Enum.map(Locales.all(), &%{&1 | live: true, auto: true})

  describe "the list" do
    test "has thirteen locales (the ten largest economies and Spain), all live" do
      assert length(Locales.all()) == 13
      assert Enum.map(Locales.live(), & &1.code) == Enum.map(Locales.all(), & &1.code)
    end

    test "a code is the language and the country" do
      for locale <- Locales.all() do
        assert locale.code == "#{locale.language}-#{locale.country}"
      end
    end

    test "the default is English for India" do
      assert %{code: "en-in", language: "en", country: "in"} = Locales.default()
    end

    test "lists the languages once" do
      assert Locales.languages() == ["en", "hi", "es", "zh", "de", "ja", "fr", "it", "pt"]
    end
  end

  test "by_country/0 groups the live locales by country, in the order of the list" do
    assert [
             {"in", [%{code: "en-in"}, %{code: "hi-in"}]},
             {"es", [%{code: "es-es"}]},
             {"us", [%{code: "en-us"}]},
             {"cn", [%{code: "zh-cn"}]},
             {"de", [%{code: "de-de"}]},
             {"jp", [%{code: "ja-jp"}]},
             {"gb", [%{code: "en-gb"}]},
             {"fr", [%{code: "fr-fr"}]},
             {"it", [%{code: "it-it"}]},
             {"br", [%{code: "pt-br"}]},
             {"ca", [%{code: "en-ca"}, %{code: "fr-ca"}]}
           ] = Locales.by_country()
  end

  describe "fetch/1" do
    test "gives a live locale" do
      assert {:ok, %{code: "hi-in"}} = Locales.fetch("hi-in")
    end

    test "refuses a locale that is planned but not live, and anything else" do
      assert :error = Locales.fetch("es-mx")
      assert :error = Locales.fetch("xx-yy")
      assert :error = Locales.fetch("EN-IN")
      assert :error = Locales.fetch(nil)
    end
  end

  test "chain/1 goes from the locale to its language to English" do
    chain = fn code ->
      code |> then(&Enum.find(Locales.all(), fn l -> l.code == &1 end)) |> Locales.chain()
    end

    assert chain.("fr-ca") == ["fr-ca", "fr", "en"]
    assert chain.("hi-in") == ["hi-in", "hi", "en"]
    assert chain.("en-in") == ["en-in", "en"]
  end

  test "hreflang/1 and path/1" do
    assert Locales.hreflang(Locales.fetch!("hi-in")) == "hi-IN"
    assert Locales.hreflang(Locales.fetch!("es-es")) == "es-ES"
    assert Locales.path(Locales.fetch!("es-es")) == "/es-es"
  end

  describe "for_document/2" do
    test "finds the locale a document was made for" do
      assert %{code: "hi-in"} = Locales.for_document("hi", %{"country" => "in"})
      assert %{code: "es-es"} = Locales.for_document("es", %{"country" => "es"})
      assert %{code: "en-in"} = Locales.for_document("en", %{"country" => "in"})
    end

    test "falls back to the language, then to the default" do
      # Spanish for Mexico has no locale: Spain's page is the closest.
      assert %{code: "es-es"} = Locales.for_document("es", %{"country" => "mx"})
      assert %{code: "es-es"} = Locales.for_document("es", %{})
      assert %{code: "es-es"} = Locales.for_document("es", nil)
      assert %{code: "fr-fr"} = Locales.for_document("fr", %{"country" => "fr"})
      assert %{code: "fr-ca"} = Locales.for_document("fr", %{"country" => "ca"})
      assert %{code: "zh-cn"} = Locales.for_document("zh", %{"country" => "cn"})
      # Arabic has no locale: the default is the closest.
      assert %{code: "en-in"} = Locales.for_document("ar", %{"country" => "sa"})
    end
  end

  describe "guess/3" do
    test "follows the language first" do
      assert %{code: "hi-in"} = Locales.guess("hi-IN,hi;q=0.9,en;q=0.8", nil, @all)
      assert %{code: "es-es"} = Locales.guess("es", "ES", @all)
    end

    test "among the locales of a language the country decides, then the region of the language tag" do
      assert %{code: "fr-ca"} = Locales.guess("fr", "CA", @all)
      assert %{code: "fr-ca"} = Locales.guess("fr-CA,fr;q=0.9", nil, @all)
      assert %{code: "en-gb"} = Locales.guess("en-GB,en;q=0.9", nil, @all)
      # Where the visitor is beats what the browser's tag says.
      assert %{code: "en-in"} = Locales.guess("en-GB,en;q=0.9", "IN", @all)
      assert %{code: "en-us"} = Locales.guess("en", "US", @all)
      assert %{code: "en-in"} = Locales.guess("en", "XX", @all)
    end

    test "orders by quality, and ignores the wildcard" do
      assert %{code: "hi-in"} = Locales.guess("en;q=0.5,hi;q=0.9", nil, @all)
      assert %{code: "es-es"} = Locales.guess("*,es", nil, @all)
    end

    test "a language we do not have gives the locale of the country, then the default" do
      assert %{code: "es-es"} = Locales.guess("ko-KR,ko;q=0.9", "ES", @all)
      assert %{code: "en-in"} = Locales.guess("ko-KR,ko;q=0.9", "KR", @all)
      assert %{code: "en-in"} = Locales.guess(nil, nil, @all)
      assert %{code: "en-in"} = Locales.guess("", "", @all)
    end

    test "only offers the locales that are marked for it" do
      # Hindi and Spanish pages are live but not offered yet: their catalogues are still small.
      assert %{code: "en-in"} = Locales.guess("hi-IN,hi;q=0.9", "IN")
      assert %{code: "en-in"} = Locales.guess("es-ES,es;q=0.9", "ES")
    end

    test "survives rubbish" do
      assert %{code: "en-in"} = Locales.guess(";;;,,q=,-", "??", @all)
      assert %{code: "en-in"} = Locales.guess("hi;q=abc", nil, [])
    end
  end

  test "with_country/2 is the same language for another country, and not a page" do
    hindi = Locales.fetch!("hi-in")

    assert Locales.with_country(hindi, nil) == hindi
    assert Locales.with_country(hindi, "in") == hindi

    assert %{code: "hi-jp", language: "hi", country: "jp", live: false} =
             Locales.with_country(hindi, "jp")
  end
end
