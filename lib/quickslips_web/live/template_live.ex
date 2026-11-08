defmodule QuickSlipsWeb.TemplateLive do
  @moduledoc """
  A bill under its locale: `/en-in/fuel-bill-generator`. The slug is the public one, so a template that is not in
  the language of the locale is a 404 (a page in another language is not offered).

  It is a LiveView so that a link to and from it is a live navigation. The form and the preview are a script
  (`assets/js/bill`), started by the `BillApp` hook on `#bill-app`; LiveView leaves that element alone
  (`phx-update="ignore"`).
  """
  use QuickSlipsWeb, :live_view

  alias QuickSlips.Businesses
  alias QuickSlips.Documents
  alias QuickSlips.Locales
  alias QuickSlips.Regions
  alias QuickSlips.Signatures
  alias QuickSlips.Stamps
  alias QuickSlips.Templates
  alias QuickSlips.Templates.Items
  alias QuickSlipsWeb.BusinessController
  alias QuickSlipsWeb.SignatureController
  alias QuickSlipsWeb.StampController

  @impl true
  def mount(%{"locale" => code, "slug" => public_slug} = params, _session, socket) do
    locale =
      case Locales.fetch(code) do
        {:ok, locale} -> locale
        :error -> raise QuickSlipsWeb.NotFoundError
      end

    # The address decides, whatever the session says.
    Gettext.put_locale(QuickSlipsWeb.Gettext, locale.language)

    case Templates.get_public(locale, public_slug) do
      {:ok, schema} ->
        slug = schema["slug"]
        {:ok, sample} = Templates.sample(slug, locale)
        scope = socket.assigns.current_scope
        # "Edit and regenerate" (Task 8.3): the form starts with the data of an earlier document.
        document = find_document(scope, params["from"], slug)

        # A document may have been made for another country than its page: the form is that country's.
        {view_locale, currency} = document_region(locale, document)
        {:ok, region} = Regions.build(view_locale.country, currency, view_locale.language)
        {:ok, schema} = Templates.get(slug, view_locale)

        socket =
          assign(socket,
            page_title: schema["title"],
            schema: schema,
            sample: if(document, do: Items.upgrade(schema, document.data), else: sample),
            document: document,
            locale: locale,
            region: region,
            template: chosen_template(schema, document),
            text: Templates.print_text(slug, view_locale),
            fonts: QuickSlips.Fonts.urls(locale.language),
            signed_in?: signed_in?(scope),
            businesses: saved_businesses(scope),
            signatures: saved_signatures(scope),
            stamps: saved_stamps(scope),
            system_stamps: Enum.map(Stamps.system_stamps(), &StampController.system_payload/1),
            stamp_choice: stamp_choice(document),
            feedback_path: feedback_path("/#{locale.code}/#{public_slug}")
          )

        {:ok, tell_locale(socket, locale)}

      {:error, :not_found} ->
        raise QuickSlipsWeb.NotFoundError
    end
  end

  # The way to ask for a change to this template: the contact form with the kind of message chosen and this page
  # named, or nothing when there is no address to write to.
  defp feedback_path(page) do
    if QuickSlips.Contact.available?(), do: ~p"/contact?#{[topic: "change", about: page]}"
  end

  # Tells the page which locale it is in, for the LiveViews that have none in their address (see `locale.ts`).
  defp tell_locale(socket, locale) do
    if connected?(socket),
      do: push_event(socket, "locale", %{code: locale.code, lang: Locales.hreflang(locale)}),
      else: socket
  end

  # The design the document was made with, when the schema still has it; else the first.
  defp chosen_template(schema, document) do
    ids = Enum.map(schema["templates"], & &1["id"])
    if document && document.template in ids, do: document.template, else: hd(ids)
  end

  defp document_region(locale, %{options: %{"country" => country} = options}),
    do: {Locales.with_country(locale, country), options["currency"]}

  defp document_region(locale, _no_document), do: {locale, nil}

  # Only a logged-in user's own document of this template counts. Anything else is ignored, so the form
  # starts with the sample, and nobody learns whether somebody else's document exists.
  defp find_document(%{user: %{}} = scope, id, slug) when not is_nil(id),
    do: Documents.get_document_for_template(scope, id, slug)

  defp find_document(_scope, _id, _slug), do: nil

  defp saved_businesses(%{user: %{}} = scope) do
    scope
    |> Businesses.list_businesses()
    |> Enum.sort_by(&String.downcase(&1.name))
    |> Enum.map(&BusinessController.payload/1)
  end

  defp saved_businesses(_visitor), do: []

  # The signatures to choose from. Only a logged-in user has any.
  defp saved_signatures(%{user: %{}} = scope) do
    scope |> Signatures.list_signatures() |> Enum.map(&SignatureController.payload/1)
  end

  defp saved_signatures(_visitor), do: []

  # The revenue stamps to choose from. Only a logged-in user has any (the site's default is for everybody).
  defp saved_stamps(%{user: %{}} = scope) do
    scope |> Stamps.list_stamps() |> Enum.map(&StampController.payload/1)
  end

  defp saved_stamps(_visitor), do: []

  # What a document that is edited had: "system:<name>", the id of a saved stamp, or "" for the empty box.
  defp stamp_choice(%{stamp_system: id}) when is_binary(id), do: "system:" <> id
  defp stamp_choice(%{stamp_id: id}) when not is_nil(id), do: to_string(id)
  defp stamp_choice(_none), do: ""

  # Whether the chosen design has a place for a revenue stamp, and the document is for India (see `Templates.Registry`).
  defp stamp_design?(schema, template, region) do
    region["country"] == "in" and
      Enum.any?(schema["templates"], &(&1["id"] == template and &1["stamp"] == true))
  end

  # Whether the chosen design of the bill has a place for a signature (see `Templates.Registry`).
  defp signature_design?(schema, template) do
    Enum.any?(schema["templates"], &(&1["id"] == template and &1["signature"] == true))
  end

  # What the form's script says to the visitor (`assets/js/bill/i18n.ts`), in the language of the page. A
  # `{name}` in a text is filled in by the script.
  defp ui_strings do
    %{
      "quota_anonymous" =>
        gettext("%{remaining} of %{limit} free downloads left today",
          remaining: "{remaining}",
          limit: "{limit}"
        ),
      "quota_user" =>
        gettext("%{remaining} of %{limit} downloads left today",
          remaining: "{remaining}",
          limit: "{limit}"
        ),
      "creating" => gettext("Creating your PDF…"),
      "downloaded" => gettext("Downloaded."),
      "fix_fields" => gettext("Please fix the highlighted fields."),
      "limit_reached" => gettext("You've used today's free downloads."),
      "verify_failed" =>
        gettext("We couldn't verify your browser. Turn off your ad blocker, or log in."),
      "error" => gettext("Something went wrong. Please try again."),
      "preview_updating" => gettext("Updating preview…"),
      "preview_failed" => gettext("Preview could not be rendered."),
      "preview_alt" => gettext("Document preview"),
      "group_business" => gettext("Business"),
      "group_registration" => gettext("Registration"),
      "group_document" => gettext("Document"),
      "group_customer" => gettext("Customer"),
      "group_items" => gettext("Item Details"),
      "group_details" => gettext("Details"),
      "group_charges" => gettext("Charges"),
      "group_payment" => gettext("Payment"),
      "add_item" => gettext("Add item"),
      "remove_item" => gettext("Remove item %{number}", number: "{number}"),
      "subtotal" => gettext("Subtotal"),
      "amount" => gettext("Amount"),
      "pick_business" => gettext("Choose a saved business…"),
      "fill_business" => gettext("Fill from a saved business"),
      "other_rate" => gettext("Other rate…"),
      "type_rate" => gettext("Type the rate in %"),
      "signature_saved" => gettext("Signature saved."),
      "signature_error_name_blank" => gettext("Give the signature a name."),
      "signature_error_name_taken" => gettext("You already have a signature with this name."),
      "signature_error_limit_reached" =>
        gettext("You can keep up to %{max} signatures. Delete one on the Signatures page first.",
          max: Signatures.max_per_user()
        ),
      "signature_error_unsupported_type" => gettext("This is not a real PNG or JPG picture."),
      "signature_error_too_large" =>
        gettext("This picture is too big: at most 4000 pixels on a side."),
      "signature_error_file_too_large" => gettext("This file is too big. The limit is 1 MB."),
      "signature_error_no_file" => gettext("Choose a picture first."),
      "stamp_saved" => gettext("Stamp saved."),
      "stamp_error_name_blank" => gettext("Give the stamp a name."),
      "stamp_error_name_taken" => gettext("You already have a stamp with this name."),
      "stamp_error_limit_reached" =>
        gettext("You can keep up to %{max} stamps. Delete one on the Stamps page first.",
          max: Stamps.max_per_user()
        ),
      "save_seller" => gettext("Save seller details"),
      "seller_created" => gettext("Seller details saved."),
      "seller_updated" => gettext("Seller details updated."),
      "seller_error_name_blank" => gettext("Fill in the seller's name first."),
      "seller_error_tax_id_invalid" =>
        gettext("The %{label} is not valid. Check it, or leave it empty.", label: "{label}")
    }
  end

  defp turnstile_site_key(%{user: %{}}), do: nil
  defp turnstile_site_key(_anonymous), do: Application.get_env(:quickslips, :turnstile)[:site_key]
end
