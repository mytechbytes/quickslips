defmodule QuickSlips.Templates.Registry do
  @moduledoc """
  Reads every `schema.json` once at start-up and keeps the result in memory.
  """
  use GenServer

  # Slugs that would collide with real routes, including ones added in later milestones.
  # If you add another single-segment route (like /pricing), add its name here too.
  @reserved ~w(users auth dashboard dev api assets images fonts wasm uploads source
               history documents businesses credits bulk bulk-import templates
               healthz sitemap.xml sw.js favicon.ico robots.txt)

  ## Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  def list(server \\ __MODULE__), do: GenServer.call(server, :list)

  def fetch(slug, server \\ __MODULE__), do: GenServer.call(server, {:fetch, slug})

  def by_category(server \\ __MODULE__) do
    server
    |> list()
    |> Enum.group_by(& &1["category"])
    |> Enum.sort_by(fn {category, _templates} -> category end)
    |> Enum.map(fn {category, templates} ->
      %{id: slugify(category), name: category, templates: templates}
    end)
  end

  ## Server callbacks

  @impl true
  def init(opts) do
    dir = Keyword.get(opts, :dir, QuickSlips.Templates.root_dir())
    {:ok, %{templates: load!(dir)}}
  end

  @impl true
  def handle_call(:list, _from, state) do
    templates = state.templates |> Map.values() |> Enum.sort_by(& &1["title"])
    {:reply, templates, state}
  end

  def handle_call({:fetch, slug}, _from, state) do
    case Map.fetch(state.templates, slug) do
      {:ok, schema} -> {:reply, {:ok, schema}, state}
      :error -> {:reply, {:error, :not_found}, state}
    end
  end

  ## Helpers

  defp load!(dir) do
    dir
    |> Path.join("*/schema.json")
    |> Path.wildcard()
    |> Map.new(fn path ->
      schema = path |> File.read!() |> Jason.decode!()
      folder = path |> Path.dirname() |> Path.basename()

      if schema["slug"] != folder do
        raise "#{path}: slug #{inspect(schema["slug"])} must equal the folder name #{inspect(folder)}"
      end

      if folder in @reserved or not Regex.match?(~r/^[a-z0-9-]+$/, folder) do
        raise "#{path}: #{inspect(folder)} is reserved or not a valid slug"
      end

      {folder, schema}
    end)
  end

  defp slugify(text) do
    text |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-") |> String.trim("-")
  end
end
