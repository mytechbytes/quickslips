defmodule QuickSlipsWeb.TemplateController do
  use QuickSlipsWeb, :controller

  alias QuickSlips.Businesses
  alias QuickSlips.Documents
  alias QuickSlips.Regions
  alias QuickSlips.Templates
  alias QuickSlips.Templates.Items
  alias QuickSlipsWeb.Seo
  alias QuickSlipsWeb.UploadController

  # `/:locale/:slug`. The locale plug has already checked the locale; the slug is the public one, so a template
  # that is not in the language of the locale is a 404 here (a page in another language is not offered).
  def show(conn, %{"slug" => public_slug} = params) do
    locale = conn.assigns.locale

    case Templates.get_public(locale, public_slug) do
      {:ok, schema} ->
        slug = schema["slug"]
        {:ok, sample} = Templates.sample(slug, locale)
        {:ok, region} = Regions.build(locale.country)
        # "Edit and regenerate" (Task 8.3): the form starts with the data of an earlier document.
        document = find_document(conn.assigns.current_scope, params["from"], slug)

        conn
        |> assign(:page_title, schema["title"])
        |> assign(:meta_description, schema["description"])
        |> merge_assigns(Seo.bill(locale, slug))
        |> render(:show,
          schema: schema,
          sample: if(document, do: Items.upgrade(schema, document.data), else: sample),
          document: document,
          locale: locale,
          region: region,
          text: Templates.print_text(slug, locale),
          businesses: saved_businesses(conn.assigns.current_scope)
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
