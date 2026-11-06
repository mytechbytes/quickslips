defmodule QuickSlipsWeb.TemplateController do
  use QuickSlipsWeb, :controller

  alias QuickSlips.Businesses
  alias QuickSlips.Documents
  alias QuickSlips.Templates
  alias QuickSlipsWeb.UploadController

  def show(conn, %{"slug" => slug} = params) do
    case Templates.get(slug) do
      {:ok, schema} ->
        {:ok, sample} = Templates.sample(slug)
        # "Edit and regenerate" (Task 8.3): the form starts with the data of an earlier document.
        document = find_document(conn.assigns.current_scope, params["from"], slug)

        render(conn, :show,
          schema: schema,
          sample: if(document, do: document.data, else: sample),
          document: document,
          businesses: saved_businesses(conn.assigns.current_scope),
          page_title: schema["title"],
          meta_description: schema["description"]
        )

      {:error, :not_found} ->
        raise QuickSlipsWeb.NotFoundError
    end
  end

  # Only a logged-in user's own document of this template counts. Anything else is ignored, so the form
  # starts with the sample, and nobody learns whether somebody else's document exists.
  defp find_document(%{user: %{}} = scope, id, slug) when not is_nil(id),
    do: Documents.get_document_for_template(scope, id, slug)

  defp find_document(_scope, _id, _slug), do: nil

  defp saved_businesses(%{user: %{}} = scope) do
    scope
    |> Businesses.list_businesses()
    |> Enum.sort_by(&String.downcase(&1.name))
    |> Enum.map(
      &%{
        id: &1.id,
        name: &1.name,
        address: &1.address,
        gstin: &1.gstin,
        logo_url: UploadController.path(&1.logo_path),
        signature_url: UploadController.path(&1.signature_path)
      }
    )
  end

  defp saved_businesses(_visitor), do: []
end
