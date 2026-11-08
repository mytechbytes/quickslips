defmodule QuickSlips.Templates.Registry do
  @moduledoc """
  Reads every template folder once at start-up and keeps the result in memory: for each template, what it looks
  like to a visitor of each live locale that its language covers (see `QuickSlips.Templates.Localizer`).

  A template folder that is wrong stops the start-up with a message that says what to fix: a bad slug, a
  language that is declared but not translated, two templates with the same public address in a locale.
  """
  use GenServer

  alias QuickSlips.Locales
  alias QuickSlips.Templates.Localizer

  # Slugs that would collide with real routes, including ones added in later milestones. A template's own slug
  # is not a public address any more (that is `public_slug`, under the locale), but the old addresses of the
  # live templates still lead somewhere, so the names stay taken.
  @reserved ~w(users auth dashboard dev api assets images fonts wasm uploads source
               history documents businesses credits bulk bulk-import templates
               healthz sitemap sitemap.xml sitemap.xsl terms privacy disclaimer sw.js favicon.ico robots.txt admin)

  # Field keys the server fills in itself (the names of a business's pictures), so a template can't use them.
  @reserved_keys ~w(logo signature)

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @doc "Every template as a visitor of the default locale sees it, by title."
  def list(server \\ __MODULE__), do: GenServer.call(server, :list)

  @doc "One template for the default locale: `{:ok, schema}` or `{:error, :not_found}`."
  def fetch(id, server \\ __MODULE__), do: GenServer.call(server, {:fetch, id})

  @doc """
  What a visitor of a locale (its code) sees of a template: `{:ok, %{schema: _, print: _, sample: _}}`, or
  `{:error, :not_found}` when the template does not exist or is not in the language of the locale.

  With a locale map instead of a code, a locale that has no page of its own (Hindi for Japan: a document made for
  another country than its page) is worked out on the spot from the same files.
  """
  def view(id, locale_or_code, server \\ __MODULE__),
    do: GenServer.call(server, {:view, id, locale_or_code})

  @doc "The templates of a locale, by title."
  def list_for(locale_code, server \\ __MODULE__),
    do: GenServer.call(server, {:list_for, locale_code})

  @doc "`{:ok, id}` for the public address (the slug under the locale) of a template."
  def fetch_by_public_slug(locale_code, public_slug, server \\ __MODULE__),
    do: GenServer.call(server, {:by_public_slug, locale_code, public_slug})

  @doc "The public slug of a template in each locale it is in, like `%{\"en-in\" => \"fuel-bill-generator\"}`."
  def public_slugs(id, server \\ __MODULE__), do: GenServer.call(server, {:public_slugs, id})

  @doc "The categories of a locale's templates, `[%{key: \"Travel\", name: \"यात्रा\"}, ...]`, by key."
  def categories(locale_code, server \\ __MODULE__),
    do: GenServer.call(server, {:categories, locale_code})

  @doc """
  What a link to each template of a locale needs: `%{"fuel-bill" => %{name: "Fuel Bill", title: _, public_slug: _,
  category: "Travel", category_name: _}}`. It is small on purpose: a whole schema is big to copy out of the registry,
  and a footer asks on every page.
  """
  def names(locale_code, server \\ __MODULE__), do: GenServer.call(server, {:names, locale_code})

  ## Server callbacks

  @impl true
  def init(opts) do
    dir = Keyword.get(opts, :dir, QuickSlips.Templates.root_dir())
    {:ok, load!(dir)}
  end

  @impl true
  def handle_call(:list, _from, state) do
    default = Locales.default().code

    templates =
      state.views
      |> Enum.filter(fn {{_id, code}, _view} -> code == default end)
      |> Enum.map(fn {_key, view} -> view.schema end)
      |> Enum.sort_by(& &1["title"])

    {:reply, templates, state}
  end

  def handle_call({:fetch, id}, _from, state) do
    case Map.fetch(state.views, {id, Locales.default().code}) do
      {:ok, view} -> {:reply, {:ok, view.schema}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:view, id, code}, _from, state) when is_binary(code) do
    case Map.fetch(state.views, {id, code}) do
      {:ok, view} -> {:reply, {:ok, view}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:view, id, %{code: code} = locale}, from, state) do
    case Map.fetch(state.views, {id, code}) do
      {:ok, view} -> {:reply, {:ok, view}, state}
      :error -> handle_call({:compute, id, locale}, from, state)
    end
  end

  def handle_call({:compute, id, locale}, _from, state) do
    with {:ok, entry} <- Map.fetch(state.entries, id),
         true <- locale.language in (entry.schema["languages"] || ["en"]) do
      {:reply, {:ok, make_view(entry, state.shared, locale)}, state}
    else
      _ -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:list_for, code}, _from, state) do
    {:reply, schemas_for(state, code), state}
  end

  def handle_call({:by_public_slug, code, slug}, _from, state) do
    case Map.fetch(state.slugs, {code, slug}) do
      {:ok, id} -> {:reply, {:ok, id}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:public_slugs, id}, _from, state) do
    slugs =
      for {{^id, code}, view} <- state.views, into: %{}, do: {code, view.schema["public_slug"]}

    {:reply, slugs, state}
  end

  def handle_call({:names, code}, _from, state) do
    names =
      for {{id, ^code}, %{schema: schema}} <- state.views, into: %{} do
        {id,
         %{
           name: schema["name"],
           title: schema["title"],
           public_slug: schema["public_slug"],
           category: schema["category"],
           category_name: schema["category_name"]
         }}
      end

    {:reply, names, state}
  end

  def handle_call({:categories, code}, _from, state) do
    categories =
      state
      |> schemas_for(code)
      |> Enum.uniq_by(& &1["category"])
      |> Enum.map(&%{key: &1["category"], name: &1["category_name"]})
      |> Enum.sort_by(& &1.key)

    {:reply, categories, state}
  end

  defp schemas_for(state, code) do
    for({{_id, ^code}, view} <- state.views, do: view.schema)
    |> Enum.sort_by(& &1["title"])
  end

  ## Loading

  defp load!(dir) do
    shared = read_texts(Path.join([dir, "_shared", "text"]))

    entries =
      dir
      |> Path.join("*/schema.json")
      |> Path.wildcard()
      |> Map.new(&load_template!/1)

    check_shared!(shared, entries)
    views = build_views!(entries, shared)

    slugs =
      Enum.reduce(views, %{}, fn {{id, code}, view}, slugs ->
        key = {code, view.schema["public_slug"]}

        case slugs do
          %{^key => other} ->
            raise "#{id} and #{other} have the same public slug #{inspect(elem(key, 1))} in #{code}"

          _ ->
            Map.put(slugs, key, id)
        end
      end)

    %{views: views, slugs: slugs, entries: entries, shared: shared}
  end

  defp load_template!(path) do
    schema = path |> File.read!() |> Jason.decode!()
    folder = path |> Path.dirname() |> Path.basename()

    if schema["slug"] != folder do
      raise "#{path}: slug #{inspect(schema["slug"])} must equal the folder name #{inspect(folder)}"
    end

    if folder in @reserved or folder in Enum.map(Locales.all(), & &1.code) or
         not Regex.match?(~r/^[a-z0-9-]+$/, folder) do
      raise "#{path}: #{inspect(folder)} is reserved or not a valid slug"
    end

    for %{"key" => key} <- schema["fields"], key in @reserved_keys do
      raise "#{path}: the field key #{inspect(key)} is reserved for business pictures"
    end

    dir = Path.dirname(path)
    texts = read_texts(Path.join(dir, "text"))
    languages = schema["languages"] || ["en"]
    check_translations!(path, texts, languages)

    schema =
      Map.update!(
        schema,
        "templates",
        &Enum.map(&1, fn design -> mark_signature(design, dir) end)
      )

    {folder, %{schema: schema, texts: texts, sample: read_sample(dir)}}
  end

  # Whether a design has a place for a signature, as `"signature": true` on it: the page offers the choice of a
  # saved signature only for those. A layout has one when it uses the `signature-block` helper, which leaves room
  # to sign by hand when there is no picture, or reads the `"signature"` picture itself.
  defp mark_signature(%{"id" => id} = design, dir) do
    file = Path.join(dir, id <> ".typ")

    case File.read(file) do
      {:ok, source} ->
        Map.put(
          design,
          "signature",
          String.contains?(source, ["signature-block(", ~s("signature")])
        )

      {:error, reason} ->
        raise "#{file}: the layout of the design #{inspect(id)} can't be read (#{:file.format_error(reason)})"
    end
  end

  # A template that declares a language must be translated into it completely: every key of its English text
  # file. Without the check a missing word would quietly show up in English on a Hindi page.
  defp check_translations!(path, texts, languages) do
    reference = texts |> Map.get("en", %{}) |> Map.delete("sample")

    for language <- languages -- ["en"] do
      case Localizer.missing(reference, Map.get(texts, language)) do
        [] -> :ok
        missing -> raise "#{path}: text/#{language}.json is missing #{Enum.join(missing, ", ")}"
      end
    end
  end

  # The words every template shares (months, categories) must exist in each language a template is in.
  defp check_shared!(shared, entries) do
    languages =
      entries
      |> Enum.flat_map(fn {_id, entry} -> entry.schema["languages"] || ["en"] end)
      |> Enum.uniq()

    for language <- languages -- ["en"] do
      case Localizer.missing(Map.get(shared, "en", %{}), Map.get(shared, language)) do
        [] -> :ok
        missing -> raise "_shared/text/#{language}.json is missing #{Enum.join(missing, ", ")}"
      end
    end
  end

  defp build_views!(entries, shared) do
    for {id, entry} <- entries,
        locale <- Locales.live(),
        locale.language in (entry.schema["languages"] || ["en"]),
        into: %{} do
      view = make_view(entry, shared, locale)
      check_public_slug!(id, locale, view.schema["public_slug"])

      {{id, locale.code}, view}
    end
  end

  defp make_view(entry, shared, locale) do
    localized = Localizer.localize(entry.schema, entry.texts, shared, locale)

    %{
      schema: localized,
      print: Localizer.print_text(localized, entry.texts, shared, locale),
      sample: Localizer.sample(entry.sample, entry.texts, locale)
    }
  end

  defp check_public_slug!(id, locale, slug) do
    unless is_binary(slug) and Regex.match?(~r/^[a-z0-9-]+$/, slug) do
      raise "#{id}: the public slug #{inspect(slug)} in #{locale.code} must be lowercase letters, digits and hyphens"
    end
  end

  # `%{"en" => %{...}, "hi" => %{...}}` from the `*.json` files of a folder; none when the folder is not there.
  defp read_texts(dir) do
    dir
    |> Path.join("*.json")
    |> Path.wildcard()
    |> Map.new(fn path ->
      {Path.basename(path, ".json"), path |> File.read!() |> Jason.decode!()}
    end)
  end

  defp read_sample(dir) do
    case File.read(Path.join(dir, "sample.json")) do
      {:ok, json} -> Jason.decode!(json)
      {:error, _} -> %{}
    end
  end
end
