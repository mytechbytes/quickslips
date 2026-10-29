defmodule QuickSlipsWeb.GenerateController do
  use QuickSlipsWeb, :controller

  alias QuickSlips.Templates.Validator
  alias QuickSlips.Templates
  alias QuickSlips.Render.Renderer

  action_fallback QuickSlipsWeb.FallbackController

  def create(conn, %{"slug" => slug, "template" => template, "data" => data}) when is_map(data) do
    with {:ok, schema} <- Templates.get(slug),
         {:ok, clean} <- Validator.validate(schema, data),
         {:ok, pdf} <- Renderer.render(slug, template, clean) do
      send_download(conn, {:binary, pdf},
        filename: "#{slug}.pdf",
        content_type: "application/pdf"
      )
    end
  end

  def create(_conn, _params), do: {:error, :bad_request}
end
