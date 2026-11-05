defmodule QuickSlipsWeb.TemplateController do
  use QuickSlipsWeb, :controller

  alias QuickSlips.Businesses
  alias QuickSlips.Templates

  def show(conn, %{"slug" => slug}) do
    case Templates.get(slug) do
      {:ok, schema} ->
        {:ok, sample} = Templates.sample(slug)

        render(conn, :show,
          schema: schema,
          sample: sample,
          businesses: saved_businesses(conn.assigns.current_scope),
          page_title: schema["title"],
          meta_description: schema["description"]
        )

      {:error, :not_found} ->
        raise QuickSlipsWeb.NotFoundError
    end
  end

  defp saved_businesses(%{user: %{}} = scope) do
    scope
    |> Businesses.list_businesses()
    |> Enum.sort_by(&String.downcase(&1.name))
    |> Enum.map(&%{id: &1.id, name: &1.name, address: &1.address, gstin: &1.gstin})
  end

  defp saved_businesses(_visitor), do: []
end
