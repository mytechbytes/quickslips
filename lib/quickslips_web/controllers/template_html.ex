defmodule QuickSlipsWeb.TemplateHTML do
  use QuickSlipsWeb, :html

  embed_templates "template_html/*"

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
      "add_item" => gettext("Add item"),
      "remove_item" => gettext("Remove item %{number}", number: "{number}"),
      "subtotal" => gettext("Subtotal"),
      "amount" => gettext("Amount"),
      "pick_business" => gettext("Choose a saved business…"),
      "fill_business" => gettext("Fill from a saved business")
    }
  end

  defp turnstile_site_key(%{user: %{}}), do: nil
  defp turnstile_site_key(_anonymous), do: Application.get_env(:quickslips, :turnstile)[:site_key]
end
