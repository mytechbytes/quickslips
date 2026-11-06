defmodule QuickSlipsWeb.HistoryController do
  use QuickSlipsWeb, :controller

  alias QuickSlips.Businesses
  alias QuickSlips.Documents
  alias QuickSlips.Render.Renderer
  alias QuickSlips.Templates
  alias QuickSlips.Templates.Validator

  @doc """
  "Download again": the PDF is made again from the saved data. It is the same document, so it does not use
  up one of the day's downloads.
  """
  def download(conn, %{"id" => id}) do
    scope = conn.assigns.current_scope
    # Looked up through the scope: somebody else's document raises, which is a 404.
    document = Documents.get_document!(scope, id)
    business = document.business_id && Businesses.get_business!(scope, document.business_id)
    %{data: image_names, files: files} = Businesses.render_assets(business)

    # The template may have changed since the document was saved, so the data is checked again.
    with {:ok, schema} <- Templates.get(document.slug),
         {:ok, clean} <- Validator.validate(schema, document.data),
         {:ok, pdf} <-
           Renderer.render(document.slug, document.template, Map.merge(clean, image_names),
             assets: files
           ) do
      send_download(conn, {:binary, pdf},
        filename: "#{document.slug}.pdf",
        content_type: "application/pdf"
      )
    else
      {:error, _reason} ->
        conn
        |> put_flash(
          :error,
          "This document can't be made again. Use Edit and regenerate instead."
        )
        |> redirect(to: ~p"/history")
    end
  end
end
