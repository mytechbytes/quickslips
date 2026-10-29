defmodule QuickSlipsWeb.TemplateController do
  use QuickSlipsWeb, :controller

  alias QuickSlips.Templates

  def show(conn, %{"slug" => slug}) do
    case Templates.get(slug) do
      {:ok, schema} ->
        {:ok, sample} = Templates.sample(slug)
        render(conn, :show,
          schema: schema,
          sample: sample,
          page_title: schema["title"],
          meta_description: schema["description"]
        )
      {:error, :not_found} ->
        raise QuickSlipsWeb.NotFoundError
    end
  end
end
