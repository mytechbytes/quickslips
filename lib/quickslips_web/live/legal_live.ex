defmodule QuickSlipsWeb.LegalLive do
  @moduledoc """
  The legal pages: `/terms`, `/privacy` and `/disclaimer`, one LiveView and a `live_action` for each. Their words
  are in `QuickSlipsWeb.LegalComponents`, in English only, and a visitor whose language is another is told so.

  They are pages of the `:current_user` live session like every public page, so that a click on a footer link is a
  live navigation, and they sit above `/:locale` in the router. They have no address under a locale: one text, one
  address.
  """
  use QuickSlipsWeb, :live_view

  import QuickSlipsWeb.LegalComponents

  @titles %{terms: "Terms of use", privacy: "Privacy policy", disclaimer: "Disclaimer"}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     assign(socket,
       page_title: Map.fetch!(@titles, socket.assigns.live_action),
       contact_email: QuickSlips.Site.contact_email()
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale}>
      <div class="mx-auto max-w-3xl py-10">
        <p
          :if={@locale.language != "en"}
          id="legal-english-only"
          class="mb-8 flex items-center gap-x-2 rounded-card bg-info-soft px-4 py-3 text-sm/6 text-ink"
        >
          <.icon name="hero-language" class="size-5 shrink-0 text-info" />
          {gettext("This page is only available in English.")}
        </p>

        <.terms :if={@live_action == :terms} contact_email={@contact_email} />
        <.privacy :if={@live_action == :privacy} contact_email={@contact_email} />
        <.disclaimer :if={@live_action == :disclaimer} contact_email={@contact_email} />
      </div>
    </Layouts.app>
    """
  end
end
