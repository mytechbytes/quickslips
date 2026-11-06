defmodule QuickSlips.Fonts do
  @moduledoc """
  The fonts a document needs, by language. Latin, Devanagari and the accents of Spanish, French, German, Italian
  and Portuguese are in Noto Sans, which every document has. Chinese and Japanese need their own fonts, which are
  15 to 20 MB each: they sit in `priv/fonts` next to Noto Sans when the language goes live, and only the
  documents and the browser previews in that language load them.

  To add a language: put the files in `priv/fonts` (`mix assets.setup` copies the folder for the browser), and
  name the family here.
  """

  @base ["Noto Sans"]
  @base_files ["NotoSans-Regular.ttf", "NotoSans-Bold.ttf"]

  # language => {family, files}. Not there yet: the files are added when the locale goes live.
  @extra %{
    "zh" => {"Noto Sans SC", ["NotoSansSC-Regular.otf", "NotoSansSC-Bold.otf"]},
    "ja" => {"Noto Sans JP", ["NotoSansJP-Regular.otf", "NotoSansJP-Bold.otf"]}
  }

  @doc "The font families of a language, in the order they are tried: `[\"Noto Sans\", \"Noto Sans JP\"]`."
  def families(language) do
    case @extra[language] do
      {family, _files} -> @base ++ [family]
      nil -> @base
    end
  end

  @doc "The font files of a language that exist: what the browser preview loads, as web paths."
  def urls(language) do
    extra =
      case @extra[language] do
        {_family, files} -> files
        nil -> []
      end

    for file <- @base_files ++ extra, File.exists?(Path.join(dir(), file)), do: "/fonts/" <> file
  end

  defp dir, do: Application.app_dir(:quickslips, "priv/fonts")
end
