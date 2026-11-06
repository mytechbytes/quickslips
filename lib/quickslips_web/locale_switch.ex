defmodule QuickSlipsWeb.LocaleSwitch do
  @moduledoc """
  Where a visitor lands after choosing another locale (a language and a country).

    * on a bill (`/en-in/fuel-bill-generator`) it is the same bill in the new locale, when the bill is there;
      when it is not, the catalogue of the new locale (`:unavailable`, so the page can say why);
    * on a catalogue (`/en-in`) it is the catalogue of the new locale;
    * on any other page (the log-in page, the dashboard) it is the same page: those pages have no locale in
      their address and take it from what the visitor chose.

  The place the visitor comes from arrives from outside (a form field, a `Referer`), so it is only followed when
  it is a path on this site.
  """

  alias QuickSlips.Locales
  alias QuickSlips.Templates

  @max_length 2000

  @doc """
  The path itself when it stays on this site, else `nil`: it has to start with a single `/` and hold nothing
  that could end the header or make the browser leave the site.
  """
  def safe_path(path) when is_binary(path) and byte_size(path) <= @max_length do
    if String.starts_with?(path, "/") and not String.starts_with?(path, "//") and
         not String.contains?(path, ["\\", "\r", "\n", "\0"]),
       do: path
  end

  def safe_path(_path), do: nil

  @doc """
  `{path, :same | :unavailable}`: where to send a visitor who is on `from` (a safe path with its query) and chose
  `locale`. `:unavailable` means the page they were on does not exist in that locale.
  """
  def target(from, locale) do
    %URI{path: path, query: query} = URI.parse(from)

    case String.split(path || "/", "/", trim: true) do
      [first] ->
        if locale_like?(first), do: {Locales.path(locale), :same}, else: {from, :same}

      [first, slug] ->
        if locale_like?(first), do: bill(first, slug, query, locale), else: {from, :same}

      [first | _] ->
        if locale_like?(first), do: {Locales.path(locale), :unavailable}, else: {from, :same}

      [] ->
        {from, :same}
    end
  end

  defp bill(old_code, slug, query, locale) do
    with {:ok, old} <- Locales.fetch(old_code),
         {:ok, schema} <- Templates.get_public(old, slug),
         path when is_binary(path) <- Templates.public_path(schema["slug"], locale) do
      {path <> if(query in [nil, ""], do: "", else: "?" <> query), :same}
    else
      _ -> {Locales.path(locale), :unavailable}
    end
  end

  # `en-in`, `hi-in`: what the first segment of an address looks like when it is a locale.
  defp locale_like?(segment), do: Regex.match?(~r/^[a-z]{2}-[a-z]{2}$/, segment)
end
