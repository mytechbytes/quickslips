defmodule QuickSlipsWeb.HistoryController do
  use QuickSlipsWeb, :controller

  alias QuickSlips.Businesses
  alias QuickSlips.Documents
  alias QuickSlips.Locales
  alias QuickSlips.Render.Renderer
  alias QuickSlips.Signatures
  alias QuickSlips.Stamps
  alias QuickSlips.Templates
  alias QuickSlips.Templates.Items
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

    # The signature that was chosen when the document was made. If it has been deleted since, the column is empty
    # (the database does that), and the document is made with the place to sign by hand.
    signature = Signatures.get_signature(scope, document.signature_id)
    driver_signature = Signatures.get_signature(scope, document.driver_signature_id)

    extras =
      for {slot, id} <- document.options["signatures"] || %{},
          signature = Signatures.get_signature(scope, id),
          into: %{} do
        {slot, signature}
      end

    # The revenue stamp the same way: a saved one that is gone is the empty box, and the site's default is a flag.
    stamp =
      if document.stamp_system,
        do: {:system, document.stamp_system},
        else: Stamps.get_stamp(scope, document.stamp_id)

    %{data: image_names, files: files} =
      Businesses.render_assets(business, signature, stamp, driver_signature, extras)

    # The document is made again in the language and for the country it was made for.
    locale = Locales.for_document(document.language, document.options)
    country = document.options["country"]
    locale = Locales.with_country(locale, country)

    # The template may have changed since the document was saved, so the data is checked again.
    with {:ok, schema} <- Templates.get(document.slug, locale),
         {:ok, clean} <- Validator.validate(schema, Items.upgrade(schema, document.data)),
         {:ok, pdf} <-
           Renderer.render(
             document.slug,
             document.template,
             clean
             |> Map.merge(image_names)
             |> Map.merge(
               Templates.paper_data(schema, document.template, document.options["paper"])
             )
             |> Map.merge(
               Templates.margin_data(schema, document.template, document.options["margin"])
             )
             |> Map.merge(watermark_data(document.options["watermark"])),
             assets: files,
             locale: Locales.for_document(document.language, document.options).code,
             country: country,
             currency: document.options["currency"]
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

  # The watermark of a document made again: a text one only (a picture is not kept in the history).
  defp watermark_data(%{} = settings) do
    {:ok, %{data: data}} = QuickSlips.Watermark.prepare(settings)
    data
  end

  defp watermark_data(_none), do: %{}
end
