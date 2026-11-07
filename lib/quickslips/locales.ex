defmodule QuickSlips.Locales do
  @moduledoc """
  The locales of the site. A locale is a language together with a country, written `en-in`, `hi-in`,
  `es-es`. It is the first segment of every public address (`/en-in/fuel-bill-generator`).

  This list is the one place that says which locales exist:

    * a `live: true` locale has pages; a locale that is not live is planned and answers with a 404;
    * an `auto: true` locale may be offered to a visitor who has not chosen one (see `guess/3`). Turn it on
      once the locale has a catalogue big enough to be a first page.
  """

  # The ten largest economies and their languages, and Spain (live since the first release). All thirteen
  # are live (Chinese and Japanese bring their fonts, see `QuickSlips.Fonts`). The English
  # locales have a first page worth guessing (`auto`): all the bills are in English.
  @locales [
    %{code: "en-in", language: "en", country: "in", name: "English", live: true, auto: true},
    %{code: "hi-in", language: "hi", country: "in", name: "हिन्दी", live: true, auto: false},
    %{code: "es-es", language: "es", country: "es", name: "Español", live: true, auto: false},
    %{code: "en-us", language: "en", country: "us", name: "English", live: true, auto: true},
    %{code: "zh-cn", language: "zh", country: "cn", name: "简体中文", live: true, auto: false},
    %{code: "de-de", language: "de", country: "de", name: "Deutsch", live: true, auto: false},
    %{code: "ja-jp", language: "ja", country: "jp", name: "日本語", live: true, auto: false},
    %{code: "en-gb", language: "en", country: "gb", name: "English", live: true, auto: true},
    %{code: "fr-fr", language: "fr", country: "fr", name: "Français", live: true, auto: false},
    %{code: "it-it", language: "it", country: "it", name: "Italiano", live: true, auto: false},
    %{code: "pt-br", language: "pt", country: "br", name: "Português", live: true, auto: false},
    %{code: "en-ca", language: "en", country: "ca", name: "English", live: true, auto: true},
    %{code: "fr-ca", language: "fr", country: "ca", name: "Français", live: true, auto: false}
  ]

  @doc "Every locale, live or not."
  def all, do: @locales

  @doc "The locales that have pages."
  def live, do: Enum.filter(@locales, & &1.live)

  @doc """
  The live locales grouped by country, in the order of the list: `[{"in", [en-in, hi-in]}, {"es", [es-es]}]`. A
  visitor picks a country, and then a language that the country has.
  """
  def by_country do
    live = live()

    for country <- live |> Enum.map(& &1.country) |> Enum.uniq(),
        do: {country, Enum.filter(live, &(&1.country == country))}
  end

  @doc "The locale a visitor gets when nothing says otherwise."
  def default, do: fetch!("en-in")

  @doc "`{:ok, locale}` for the code of a live locale, `:error` for anything else."
  def fetch(code) when is_binary(code) do
    case Enum.find(live(), &(&1.code == code)) do
      nil -> :error
      locale -> {:ok, locale}
    end
  end

  def fetch(_code), do: :error

  def fetch!(code) do
    {:ok, locale} = fetch(code)
    locale
  end

  @doc "The languages of all locales, like `[\"en\", \"hi\", \"es\"]`."
  def languages, do: @locales |> Enum.map(& &1.language) |> Enum.uniq()

  @doc """
  Where to look for a word of this locale, most specific first: `es-mx` looks in `es-mx`, then `es`, then
  `en`. The same list serves the text files of a template.
  """
  def chain(%{code: code, language: language}), do: Enum.uniq([code, language, "en"])

  @doc "The tag for `lang` and `hreflang`, like `hi-IN`."
  def hreflang(%{language: language, country: country}),
    do: "#{language}-#{String.upcase(country)}"

  @doc """
  The locale of a document that is made for another country than its page: the same language, the other country
  (Hindi for Japan). It is not a page, so it has no `live` locale of its own.
  """
  def with_country(locale, nil), do: locale
  def with_country(%{country: country} = locale, country), do: locale

  def with_country(locale, country),
    do: %{
      locale
      | code: "#{locale.language}-#{country}",
        country: country,
        live: false,
        auto: false
    }

  @doc "The path of the home page of a locale."
  def path(%{code: code}), do: "/" <> code

  @doc """
  The live locale a saved document belongs to, from the `language` and the `options` it was saved with. A
  document whose language or country is not live (any more) belongs to the closest locale, then to the
  default one.
  """
  def for_document(language, options) do
    country = is_map(options) && options["country"]
    matches = Enum.filter(live(), &(&1.language == language))

    Enum.find(matches, &(&1.country == country)) || List.first(matches) || default()
  end

  @doc """
  The locale to send a visitor to when they chose none, from the `Accept-Language` header and the country
  (`CF-IPCountry`, the two letters Cloudflare adds). The language comes first, since it decides what the
  visitor can read; among the locales of that language the country decides. Only `auto` locales are
  offered, and `default/0` is the last resort.
  """
  def guess(accept_language, country, locales \\ nil) do
    candidates = locales || Enum.filter(live(), & &1.auto)
    country = is_binary(country) && String.downcase(country)

    by_language =
      accept_language
      |> parse_accept_language()
      |> Enum.find_value(fn {language, region} ->
        case Enum.filter(candidates, &(&1.language == language)) do
          [] ->
            nil

          matches ->
            Enum.find(matches, &(&1.country == country)) ||
              Enum.find(matches, &(&1.country == region)) || hd(matches)
        end
      end)

    by_language || Enum.find(candidates, &(&1.country == country)) || default()
  end

  # "hi-IN,hi;q=0.9,en;q=0.8" -> [{"hi", "in"}, {"hi", nil}, {"en", nil}], best first.
  defp parse_accept_language(header) when is_binary(header) do
    header
    |> String.split(",", trim: true)
    |> Enum.map(&parse_language_tag/1)
    |> Enum.reject(&is_nil/1)
    |> Enum.sort_by(fn {_language, _region, quality} -> -quality end)
    |> Enum.map(fn {language, region, _quality} -> {language, region} end)
  end

  defp parse_accept_language(_header), do: []

  defp parse_language_tag(part) do
    [tag | params] = part |> String.trim() |> String.split(";")

    quality =
      Enum.find_value(params, 1.0, fn param ->
        with "q=" <> value <- String.trim(param),
             {quality, _rest} <- Float.parse(value) do
          quality
        else
          _ -> nil
        end
      end)

    case tag |> String.trim() |> String.downcase() |> String.split("-") do
      ["*" | _] -> nil
      [language, <<_::binary-size(2)>> = region | _] -> {language, region, quality}
      [language | _] when language != "" -> {language, nil, quality}
      _ -> nil
    end
  end
end
