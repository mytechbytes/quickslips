defmodule QuickSlipsWeb.TemplateController do
  use QuickSlipsWeb, :controller

  alias QuickSlips.Templates

  def show(conn, %{"slug" => slug}) do
    case Templates.get(slug) do
      {:ok, schema} ->
        render(conn, :show,
          schema: schema,
          page_title: schema["title"],
          meta_description: schema["description"]
        )
      {:error, :not_found} ->
        raise QuickSlipsWeb.NotFoundError
    end
  end
end
