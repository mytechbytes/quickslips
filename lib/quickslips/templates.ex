defmodule QuickSlips.Templates do
  @moduledoc """
  The catalogue of bill templates. Data lives in `priv/bill_templates/<slug>/`.
  """

  alias QuickSlips.Templates.Registry

  @doc "Directory that holds all template folders."
  def root_dir, do: Application.app_dir(:quickslips, "priv/bill_templates")

  @doc "Directory of one template."
  def template_dir(slug), do: Path.join(root_dir(), slug)

  def list, do: Registry.list()

  @doc "Categories for the home page: `[%{id: _, name: _, templates: [...]}, ...]`."
  def list_by_category, do: Registry.by_category()

  @doc "`{:ok, schema}` or `{:error, :not_found}`."
  def get(slug) when is_binary(slug), do: Registry.fetch(slug)

  @doc "`{:ok, sample_map}` for a template."
  def sample(slug) do
    with {:ok, _schema} <- get(slug) do
      {:ok, slug |> template_dir() |> Path.join("sample.json") |> File.read!() |> Jason.decode!()}
    end
  end
end
