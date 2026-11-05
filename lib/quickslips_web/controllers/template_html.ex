defmodule QuickSlipsWeb.TemplateHTML do
  use QuickSlipsWeb, :html

  embed_templates "template_html/*"

  defp turnstile_site_key(%{user: %{}}), do: nil
  defp turnstile_site_key(_anonymous), do: Application.get_env(:quickslips, :turnstile)[:site_key]
end
