defmodule QuickSlips.Templates do
  @moduledoc """
  The catalogue of bill templates. Data lives in `priv/bill_templates/<slug>/`.

  The `slug` of a template is its internal id: the folder name, what a saved document points at, what the
  API takes. It never changes. What a visitor sees in the address bar is the `public_slug`, which is chosen
  for search engines, can differ per language, and lives under the locale: `/es-es/generador-de-factura-de-gasolina`.
  """

  alias QuickSlips.Locales
  alias QuickSlips.Templates.Registry

  @doc "Directory that holds all template folders."
  def root_dir, do: Application.app_dir(:quickslips, "priv/bill_templates")

  @doc "Directory of one template."
  def template_dir(slug), do: Path.join(root_dir(), slug)

  @doc "Every template as a visitor of the default locale (English, India) sees it."
  def list, do: Registry.list()

  @doc "The templates a locale has, as its visitors see them: in their language, by title."
  def list(%{code: code}), do: Registry.list_for(code)

  @doc "The categories of the templates of a locale: `[%{key: \"Travel\", name: \"Viajes\"}, ...]`."
  def categories(%{code: code}), do: Registry.categories(code)

  @doc "`{:ok, schema}` of a template (default locale) by its internal id, or `{:error, :not_found}`."
  def get(slug) when is_binary(slug), do: Registry.fetch(slug)

  @doc "The same as `get/1`, in the language of `locale`; `{:error, :not_found}` when the template has none."
  def get(slug, %{code: _} = locale) when is_binary(slug) do
    with {:ok, view} <- Registry.view(slug, locale), do: {:ok, view.schema}
  end

  @doc "The template that lives at `public_slug` under a locale, `{:ok, schema}` in that locale's language."
  def get_public(%{code: code} = locale, public_slug) when is_binary(public_slug) do
    with {:ok, id} <- Registry.fetch_by_public_slug(code, public_slug), do: get(id, locale)
  end

  @doc "Whether the template is in the language of `locale`."
  def supports?(slug, locale), do: match?({:ok, _}, get(slug, locale))

  @doc "The path of a template's page in a locale, like `/en-in/fuel-bill-generator`, or `nil`."
  def public_path(slug, %{code: code}) do
    case Registry.public_slugs(slug) do
      %{^code => public_slug} -> "/#{code}/#{public_slug}"
      _ -> nil
    end
  end

  @doc """
  Where a template is in each locale, for the `hreflang` links of its page: `[{locale, public_slug}, ...]`.
  """
  def alternates(slug) do
    slugs = Registry.public_slugs(slug)
    for locale <- Locales.live(), public_slug = slugs[locale.code], do: {locale, public_slug}
  end

  @doc """
  The page an old address (the template's internal id, which used to be the whole address) now lives at:
  `{:ok, locale_code, public_slug}` or `:error`.
  """
  def legacy_target(old_slug) when is_binary(old_slug) do
    code = Locales.default().code

    case Registry.public_slugs(old_slug) do
      %{^code => public_slug} -> {:ok, code, public_slug}
      _ -> :error
    end
  end

  @doc """
  What the Typst helpers read as `text.json` for a document of `locale`, or `nil` when the template is not in
  its language.
  """
  def print_text(slug, %{code: _} = locale) do
    case Registry.view(slug, locale) do
      {:ok, view} -> view.print
      {:error, :not_found} -> nil
    end
  end

  @doc "`{:ok, sample_map}` for a template (the English sample), or `{:error, :not_found}`."
  def sample(slug), do: sample(slug, Locales.default())

  @doc "The sample a form starts with in the language of `locale`."
  def sample(slug, %{code: _} = locale) when is_binary(slug) do
    with {:ok, view} <- Registry.view(slug, locale), do: {:ok, view.sample}
  end
end
