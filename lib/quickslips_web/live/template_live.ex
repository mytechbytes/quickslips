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
  alias QuickSlips.Templates
  alias QuickSlips.Templates.Items
  alias QuickSlipsWeb.UploadController

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
            businesses: saved_businesses(scope)
          )

        {:ok, tell_locale(socket, locale)}

      {:error, :not_found} ->
        raise QuickSlipsWeb.NotFoundError
    end
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
      "type_rate" => gettext("Type the rate in %")
    }
  end

  defp turnstile_site_key(%{user: %{}}), do: nil
  defp turnstile_site_key(_anonymous), do: Application.get_env(:quickslips, :turnstile)[:site_key]
end
