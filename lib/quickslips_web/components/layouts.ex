defmodule QuickSlipsWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use QuickSlipsWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates "layouts/*"

  # The `lang` of the page: the language and country of its locale (`hi-IN`), English for the pages that have
  # none, like the log-in page.
  defp html_lang(nil), do: "en"
  defp html_lang(locale), do: QuickSlips.Locales.hreflang(locale)

  attr :title, :string, required: true
  attr :description, :string, required: true
  attr :url, :string, required: true, doc: "the canonical address of the page"
  attr :locale, :map, default: nil
  attr :alternates, :list, default: [], doc: "`[{hreflang, url}]`, the same page in other locales"

  # What a link preview is made of (Open Graph, which Facebook, WhatsApp and LinkedIn read, and the Twitter card).
  # The picture is the mark of the site; a page with a picture of its own would say so here.
  defp social_tags(assigns) do
    assigns =
      assigns
      |> assign(:image, QuickSlipsWeb.Seo.social_image())
      |> assign(:site_name, QuickSlipsWeb.Seo.site_name())
      |> assign(:og_locale, og_locale(assigns.locale))
      |> assign(:og_alternates, og_alternates(assigns.alternates, assigns.locale))

    ~H"""
    <meta property="og:type" content="website" />
    <meta property="og:site_name" content={@site_name} />
    <meta property="og:title" content={@title} />
    <meta property="og:description" content={@description} />
    <meta property="og:url" content={@url} />
    <meta :if={@og_locale} property="og:locale" content={@og_locale} />
    <meta :for={other <- @og_alternates} property="og:locale:alternate" content={other} />
    <meta property="og:image" content={@image} />
    <meta property="og:image:width" content="512" />
    <meta property="og:image:height" content="512" />
    <meta property="og:image:alt" content={@site_name} />
    <meta name="twitter:card" content="summary" />
    <meta name="twitter:title" content={@title} />
    <meta name="twitter:description" content={@description} />
    <meta name="twitter:image" content={@image} />
    """
  end

  # Open Graph writes a locale with an underscore: `hi_IN`.
  defp og_locale(nil), do: nil
  defp og_locale(locale), do: locale |> QuickSlips.Locales.hreflang() |> String.replace("-", "_")

  # The other locales the page is in, as `hi_IN`; `x-default` is not a locale.
  defp og_alternates(alternates, locale) do
    own = og_locale(locale)

    for {hreflang, _url} <- alternates,
        hreflang != "x-default",
        other = String.replace(hreflang, "-", "_"),
        other != own,
        do: other
  end

  # The structured data of a page (`QuickSlipsWeb.Seo`): a `<script>` that holds JSON, which a browser does not run.
  # The JSON is already made safe to sit in a script (no `<` in it), so it goes in as it is.
  defp json_ld_tag(nil), do: ""

  defp json_ld_tag(json) do
    Phoenix.HTML.raw([~s(<script type="application/ld+json">), json, "</script>"])
  end

  @doc """
  Renders your app layout. Every page starts with it.

  There are two shells, and the layout picks one by who is looking:

    * a visitor gets the **public shell**: a header with Log in and Sign up, and a footer;
    * a logged-in user gets the **app shell**: a dark sidebar on a laptop, a dark top bar on a phone.

  Pages never choose. They only pass `current_scope`.

  ## Examples

      <Layouts.app flash={@flash} current_scope={@current_scope}>
        <h1>Content</h1>
      </Layouts.app>

      <Layouts.app flash={@flash} current_scope={@current_scope} active={:dashboard} title="Dashboard">
        <:actions><.button navigate={~p"/"}>New document</.button></:actions>
        ...
      </Layouts.app>

  `active`, `title`, `subtitle` and `actions` only matter in the app shell: `active` highlights a
  sidebar item and `title` writes the page title band under the header.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"

  attr :current_scope, :map,
    default: nil,
    doc: "the current [scope](https://phoenix.hexdocs.pm/scopes.html)"

  attr :active, :atom,
    default: nil,
    doc: "the sidebar item to highlight, one of the keys in nav_items/0"

  attr :locale, :map,
    default: nil,
    doc: "the locale of the page (`QuickSlips.Locales`), for the language and country switch"

  attr :title, :string, default: nil, doc: "the page title (app shell)"
  attr :subtitle, :string, default: nil, doc: "a line under the title (app shell)"
  slot :actions, doc: "buttons at the right of the title (app shell)"
  slot :inner_block, required: true

  def app(assigns) do
    assigns = assign(assigns, :locale, assigns.locale || QuickSlips.Locales.default())
    if signed_in?(assigns.current_scope), do: app_shell(assigns), else: public_shell(assigns)
  end

  # The sidebar items. Add one when its page exists (Milestone 9 adds Credits and Bulk import), for example:
  #   {:credits, "Credits", "hero-banknotes", ~p"/credits"}
  defp nav_items do
    [
      {:dashboard, gettext("Dashboard"), "hero-squares-2x2", ~p"/dashboard"},
      {:history, gettext("Documents"), "hero-document-text", ~p"/history"},
      {:businesses, gettext("Saved businesses"), "hero-building-storefront", ~p"/businesses"},
      {:signatures, gettext("Signatures"), "hero-pencil", ~p"/signatures"},
      {:stamps, gettext("Stamps"), "hero-ticket", ~p"/stamps"}
    ]
  end

  ## The public shell (visitors)

  defp public_shell(assigns) do
    ~H"""
    <div class="flex min-h-screen flex-col">
      <.support_bar locale={@locale} />
      <header class="border-b border-line bg-surface">
        <nav
          aria-label={gettext("Main")}
          class="mx-auto flex max-w-8xl items-center justify-between gap-x-4 px-4 py-2 sm:px-6 lg:px-8"
        >
          <div class="flex items-center gap-x-10">
            <.wordmark id="logo" navigate={home_path(@locale)} />
            <div class="hidden lg:flex lg:gap-x-8">
              <.link
                id="nav-templates"
                navigate={home_path(@locale)}
                class="rounded-field text-sm/6 font-semibold text-ink-muted hover:text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
              >
                {gettext("Templates")}
              </.link>
            </div>
          </div>
          <div class="flex items-center gap-x-1 sm:gap-x-2">
            <.locale_menu id="locale-menu" locale={@locale} />
            <.theme_menu id="theme-menu" />
            <div class="hidden items-center gap-x-2 lg:flex">
              <.button id="header-login" variant="ghost" navigate={~p"/users/log-in"}>
                {gettext("Log in")}
              </.button>
              <.button id="header-signup" navigate={~p"/users/register"}>
                {gettext("Sign up")}
              </.button>
            </div>
            <button
              id="open-menu"
              type="button"
              command="show-modal"
              commandfor="mobile-menu"
              class="flex size-10 sm:size-9 items-center justify-center rounded-full text-ink-muted hover:bg-surface-muted hover:text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus lg:hidden"
            >
              <span class="sr-only">{gettext("Open main menu")}</span>
              <.icon name="hero-bars-3" class="size-6" />
            </button>
          </div>
        </nav>
      </header>

      <%!-- The phone menu: a dialog that slides in from the right. Elements keeps its open state. --%>
      <el-dialog phx-update="ignore" id="mobile-menu-wrapper">
        <dialog id="mobile-menu" class="backdrop:bg-transparent lg:hidden">
          <el-dialog-backdrop class="fixed inset-0 bg-overlay transition-opacity motion-reduce:transition-none data-closed:opacity-0">
          </el-dialog-backdrop>
          <div tabindex="0" class="fixed inset-0 focus:outline-none">
            <el-dialog-panel class="fixed inset-y-0 right-0 z-50 w-full overflow-y-auto bg-surface p-6 transition duration-300 ease-in-out motion-reduce:transition-none data-closed:translate-x-full sm:max-w-sm sm:ring-1 sm:ring-line">
              <div class="flex items-center justify-between">
                <.wordmark id="menu-logo" navigate={home_path(@locale)} />
                <button
                  id="close-menu"
                  type="button"
                  command="close"
                  commandfor="mobile-menu"
                  class="flex size-10 sm:size-9 items-center justify-center rounded-full text-ink-muted hover:bg-surface-muted hover:text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
                >
                  <span class="sr-only">{gettext("Close menu")}</span>
                  <.icon name="hero-x-mark" class="size-6" />
                </button>
              </div>
              <div class="mt-6 flow-root">
                <div class="-my-6 divide-y divide-line">
                  <div class="space-y-1 py-6">
                    <.link
                      id="menu-templates"
                      navigate={home_path(@locale)}
                      class="-mx-3 flex min-h-10 sm:min-h-9 items-center rounded-card px-3 py-2 text-base/7 font-semibold text-ink hover:bg-surface-muted focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
                    >
                      {gettext("Templates")}
                    </.link>
                  </div>
                  <div class="grid grid-cols-2 gap-3 py-6">
                    <.button id="menu-login" variant="secondary" navigate={~p"/users/log-in"}>
                      {gettext("Log in")}
                    </.button>
                    <.button id="menu-signup" navigate={~p"/users/register"}>
                      {gettext("Sign up")}
                    </.button>
                  </div>
                </div>
              </div>
            </el-dialog-panel>
          </div>
        </dialog>
      </el-dialog>

      <main class="mx-auto w-full max-w-8xl grow px-4 sm:px-6 lg:px-8">
        {render_slot(@inner_block)}
      </main>

      <.site_footer locale={@locale} />
    </div>

    <.flash_group flash={@flash} />
    """
  end

  ## The footer of the public pages

  attr :id, :string, required: true
  attr :url, :string, required: true
  attr :class, :any, default: nil

  @doc """
  The card that asks for support: the heart, "Keep QuickSlips free", what the money does and the button, which opens the
  page of support in a new tab. Used in the footer and in the dialog of a download.
  """
  def support_card(assigns) do
    ~H"""
    <aside
      id={@id}
      class={["rounded-card border border-accent/40 bg-accent-soft p-4 text-ink", @class]}
    >
      <div>
        <p class="flex items-center gap-x-2 text-base/6 font-semibold">
          <.icon name="hero-heart" class="size-5 shrink-0 text-accent" />
          {gettext("Keep QuickSlips free")}
        </p>
        <p class="mt-1 text-sm/6 text-ink-muted">
          {gettext(
            "QuickSlips is free for everyone and runs on a little help from people like you. If it saves you time, a coffee keeps it going."
          )}
        </p>
      </div>
      <.button
        id={"#{@id}-link"}
        href={@url}
        target="_blank"
        rel="noopener noreferrer"
        class="mt-3 shrink-0 sm:mt-0"
      >
        {gettext("Support us")} <.icon name="hero-arrow-top-right-on-square" class="size-4" />
      </.button>
    </aside>
    """
  end

  # The slim bar at the top of every page: the same ask in one line, and a way to close it. Nothing when there is no page of support.
  attr :locale, :map, required: true

  defp support_bar(assigns) do
    assigns = assign(assigns, :url, QuickSlips.Support.url(assigns.locale))

    ~H"""
    <div :if={@url} id="support-bar" class="bg-primary text-on-primary">
      <div class="mx-auto flex max-w-8xl items-center gap-x-3 px-4 py-2 text-sm/6 sm:px-6 lg:px-8">
        <.icon name="hero-heart" class="size-5 shrink-0 text-accent-soft" />
        <p class="min-w-0 flex-1">
          <span class="font-semibold">{gettext("Keep QuickSlips free")}</span>
          <span class="hidden sm:inline">
            · {gettext("QuickSlips is free for everyone. Help keep it that way.")}
          </span>
        </p>
        <a
          id="support-bar-link"
          href={@url}
          target="_blank"
          rel="noopener noreferrer"
          class="shrink-0 rounded-field font-semibold underline underline-offset-2 hover:no-underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-on-primary"
        >
          {gettext("Support us")}
        </a>
        <button
          id="support-bar-close"
          type="button"
          data-close-support-bar
          class="-mr-1.5 inline-flex size-8 shrink-0 items-center justify-center rounded-full hover:bg-on-primary/15 focus-visible:outline-2 focus-visible:outline-on-primary"
        >
          <span class="sr-only">{gettext("close")}</span>
          <.icon name="hero-x-mark" class="size-5" />
        </button>
      </div>
    </div>
    """
  end

  attr :locale, :map, required: true

  # What a visitor can go on to from any public page: the bills people ask for most, the whole catalogue, the pages
  # about the site, and then the language and country switch and the notice that the visitor answers for what the
  # documents say. The links to bills are in the language and at the addresses of the locale of the page.
  defp site_footer(assigns) do
    assigns =
      assigns
      |> assign(:popular, QuickSlipsWeb.Footer.popular(assigns.locale))
      |> assign(:more, QuickSlipsWeb.Footer.more(assigns.locale))
      |> assign(:site, site_links(assigns.locale))
      |> assign(:contact?, QuickSlips.Contact.available?())
      |> assign(:support_url, QuickSlips.Support.url(assigns.locale))

    ~H"""
    <footer id="site-footer" class="border-t border-line bg-surface">
      <div class="mx-auto max-w-8xl px-4 py-10 sm:px-6 lg:px-8">
        <.support_card
          :if={@support_url}
          id="footer-support"
          url={@support_url}
          class="mb-10 sm:flex sm:items-center sm:justify-between sm:gap-x-6"
        />
        <div class="grid gap-x-8 gap-y-10 sm:grid-cols-2 lg:grid-cols-[minmax(0,1.6fr)_repeat(3,minmax(0,1fr))]">
          <div class="sm:col-span-2 lg:col-span-1">
            <.wordmark id="footer-logo" navigate={home_path(@locale)} />
            <p id="footer-tagline" class="mt-4 max-w-sm text-sm/6 text-ink-muted">
              {gettext(
                "Make a clean bill or receipt as a PDF in seconds: fill in the form, check the preview, download. Nothing to install."
              )}
            </p>
            <p :if={@contact?} id="footer-feedback" class="mt-3 text-sm/6 text-ink-muted">
              {gettext("Want a change, have feedback, or hit a problem?")}
              <.link
                id="footer-feedback-link"
                navigate={~p"/contact"}
                class="rounded-field font-medium text-primary hover:text-primary-hover focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
              >
                {gettext("Tell us")}
              </.link>
            </p>
            <p id="footer-copyright" class="mt-4 text-sm/6 text-ink-muted">
              {gettext("© %{year} QuickSlips. All rights reserved.", year: Date.utc_today().year)}
            </p>
          </div>

          <.footer_links id="footer-popular" title={gettext("Popular bills")} links={@popular} />

          <.footer_links id="footer-more" title={gettext("More templates")} links={@more}>
            <:extra>
              <.link
                id="footer-all-templates"
                navigate={home_path(@locale)}
                class={
                  footer_link_class() ++ ["inline-flex items-center gap-x-1 font-medium text-primary"]
                }
              >
                {gettext("View all templates")} <.icon name="hero-arrow-right" class="size-4" />
              </.link>
            </:extra>
          </.footer_links>

          <.footer_links id="footer-site" title="QuickSlips" links={@site} />
        </div>

        <div class="mt-10 flex flex-col gap-4 border-t border-line pt-6 lg:flex-row lg:items-center lg:justify-between">
          <.locale_picker id="footer-locale" locale={@locale} />
          <p id="footer-notice" class="max-w-2xl text-sm/6 text-ink-muted lg:text-right">
            {gettext(
              "We create documents from the details you enter. You are responsible for their accuracy and for using them lawfully."
            )}
          </p>
        </div>
      </div>
    </footer>
    """
  end

  # The pages about QuickSlips itself, and the contact form when there is an address to send to (`CONTACT_EMAIL`).
  defp site_links(locale) do
    [
      %{label: gettext("Templates"), to: home_path(locale)},
      %{label: gettext("Sitemap"), to: ~p"/sitemap"},
      %{label: gettext("Terms"), to: ~p"/terms"},
      %{label: gettext("Privacy"), to: ~p"/privacy"},
      %{label: gettext("Disclaimer"), to: ~p"/disclaimer"}
    ] ++ contact_links() ++ support_links(locale)
  end

  # The page where people can support the site, when there is one (`SUPPORT_URL`).
  defp support_links(locale) do
    case QuickSlips.Support.url(locale) do
      url when is_binary(url) -> [%{label: gettext("Keep QuickSlips free"), href: url}]
      _none -> []
    end
  end

  defp contact_links do
    if QuickSlips.Contact.available?(),
      do: [%{label: gettext("Contact"), to: ~p"/contact"}],
      else: []
  end

  attr :id, :string, required: true
  attr :title, :string, required: true

  attr :links, :list,
    default: [],
    doc: "`[%{label: _, to: path}]`, or `%{label: _, href: url}` for a link that leaves the app"

  slot :extra, doc: "one more line after the links"

  defp footer_links(assigns) do
    ~H"""
    <nav id={@id} aria-labelledby={"#{@id}-title"}>
      <h2 id={"#{@id}-title"} class="text-sm/6 font-semibold text-ink">{@title}</h2>
      <ul class="mt-3 space-y-2">
        <li :for={link <- @links}>
          <.link :if={Map.has_key?(link, :to)} navigate={link.to} class={footer_link_class()}>
            {link.label}
          </.link>
          <.link :if={Map.has_key?(link, :href)} href={link.href} class={footer_link_class()}>
            {link.label}
          </.link>
        </li>
        <li :if={@extra != []}>{render_slot(@extra)}</li>
      </ul>
    </nav>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :icon, :string, required: true
  attr :current, :boolean, default: false, doc: "one of the pages of the menu is open"
  attr :items, :list, required: true, doc: "`[%{id:, label:, icon:, path:, current:}]`"

  # A menu of the bar at the top of the page (laptop) that opens a list of pages: the second level.
  defp top_menu(assigns) do
    ~H"""
    <el-dropdown id={@id} class="relative">
      <button
        id={"#{@id}-trigger"}
        type="button"
        aria-current={@current && "page"}
        class={top_nav_class()}
      >
        <.icon name={@icon} class="size-5 shrink-0" />{@label}
        <.icon name="hero-chevron-down" class="size-4 opacity-70" />
      </button>
      <el-menu anchor="bottom start" popover class={["w-56", QuickSlipsWeb.UI.menu_class()]}>
        <.link
          :for={item <- @items}
          id={item.id}
          navigate={item.path}
          aria-current={item.current && "page"}
          class={[
            QuickSlipsWeb.UI.menu_item_class(),
            "aria-[current=page]:bg-primary-soft aria-[current=page]:font-semibold aria-[current=page]:text-primary"
          ]}
        >
          <.icon name={item.icon} class="size-5 shrink-0 text-ink-muted" />{item.label}
        </.link>
      </el-menu>
    </el-dropdown>
    """
  end

  # A link of the menu at the top of the page (laptop), with the page that is open marked.
  defp top_nav_class do
    [
      "flex min-h-9 items-center gap-x-2 rounded-button px-3 py-1.5 text-sm/6 font-semibold whitespace-nowrap text-ink-muted hover:bg-surface-muted hover:text-ink",
      "aria-[current=page]:bg-primary-soft aria-[current=page]:text-primary focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
    ]
  end

  defp footer_link_class do
    [
      "rounded-field text-sm/6 text-ink-muted hover:text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
    ]
  end

  ## The app shell (logged-in users)

  defp app_shell(assigns) do
    assigns =
      assigns
      |> assign(:user, assigns.current_scope.user)
      |> assign(:contact?, QuickSlips.Contact.available?())
      |> assign(:admin?, QuickSlips.Accounts.admin?(assigns.current_scope.user))

    ~H"""
    <div class="flex min-h-screen flex-col">
      <.support_bar locale={@locale} />

      <%!-- Phone: a dark top bar with a menu --%>
      <div class="lg:hidden">
        <nav aria-label={gettext("Main")} class="bg-sidebar">
          <div class="mx-auto max-w-8xl px-4 sm:px-6">
            <div class="flex h-16 items-center justify-between">
              <.wordmark id="m-logo" tone={:sidebar} navigate={~p"/dashboard"} />
              <div class="-mr-2 flex items-center gap-x-1">
                <.locale_menu id="m-locale-menu" locale={@locale} on_dark />
                <.theme_menu id="m-theme-menu" on_dark />
                <button
                  id="mobile-menu-toggle"
                  type="button"
                  command="--toggle"
                  commandfor="mobile-menu"
                  class="relative inline-flex size-10 sm:size-9 items-center justify-center rounded-full text-on-sidebar/80 hover:bg-on-sidebar/10 hover:text-on-sidebar focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-on-sidebar"
                >
                  <span class="sr-only">{gettext("Open main menu")}</span>
                  <.icon name="hero-bars-3" class="size-6 in-aria-expanded:hidden" />
                  <.icon name="hero-x-mark" class="size-6 not-in-aria-expanded:hidden" />
                </button>
              </div>
            </div>
          </div>
          <el-disclosure id="mobile-menu" hidden class="block">
            <div class="space-y-1 px-2 pt-2 pb-3 sm:px-3">
              <.button id="m-new-document" navigate={home_path(@locale)} block on_dark class="mb-2">
                <.icon name="hero-plus" class="size-5" /> {gettext("New document")}
              </.button>
              <.link
                :for={{key, label, ic, path} <- nav_items()}
                id={"m-nav-#{key}"}
                navigate={path}
                aria-current={@active == key && "page"}
                class="flex min-h-10 sm:min-h-9 items-center gap-x-3 rounded-button px-3 py-2 text-base font-medium text-on-sidebar/80 hover:bg-on-sidebar/10 hover:text-on-sidebar aria-[current=page]:bg-on-sidebar/10 aria-[current=page]:text-on-sidebar focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-on-sidebar"
              >
                <.icon name={ic} class="size-5 shrink-0" />{label}
              </.link>
            </div>
            <div class="border-t border-on-sidebar/20 pt-4 pb-3">
              <div class="flex items-center px-5">
                <.avatar initials={initials(@user)} class="size-10" />
                <div class="ml-3 min-w-0">
                  <div class="truncate text-base font-medium text-on-sidebar">
                    {@user.name || @user.email}
                  </div>
                  <div class="truncate text-sm font-medium text-on-sidebar/70">{@user.email}</div>
                </div>
              </div>
              <div class="mt-3 space-y-1 px-2">
                <.link
                  id="m-settings"
                  navigate={~p"/users/settings"}
                  aria-current={@active == :settings && "page"}
                  class="flex min-h-10 sm:min-h-9 items-center gap-x-3 rounded-button px-3 py-2 text-base font-medium text-on-sidebar/80 hover:bg-on-sidebar/10 hover:text-on-sidebar aria-[current=page]:bg-on-sidebar/10 aria-[current=page]:text-on-sidebar focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-on-sidebar"
                >
                  <.icon name="hero-cog-6-tooth" class="size-5 shrink-0" /> {gettext("Settings")}
                </.link>
                <.link
                  :if={@admin?}
                  id="m-messages"
                  navigate={~p"/admin/messages"}
                  aria-current={@active == :messages && "page"}
                  class="flex min-h-10 sm:min-h-9 items-center gap-x-3 rounded-button px-3 py-2 text-base font-medium text-on-sidebar/80 hover:bg-on-sidebar/10 hover:text-on-sidebar aria-[current=page]:bg-on-sidebar/10 aria-[current=page]:text-on-sidebar focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-on-sidebar"
                >
                  <.icon name="hero-inbox" class="size-5 shrink-0" /> {gettext("Messages")}
                </.link>
                <.link
                  :if={@contact?}
                  id="m-contact"
                  navigate={~p"/contact"}
                  aria-current={@active == :contact && "page"}
                  class="flex min-h-10 sm:min-h-9 items-center gap-x-3 rounded-button px-3 py-2 text-base font-medium text-on-sidebar/80 hover:bg-on-sidebar/10 hover:text-on-sidebar aria-[current=page]:bg-on-sidebar/10 aria-[current=page]:text-on-sidebar focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-on-sidebar"
                >
                  <.icon name="hero-chat-bubble-left-right" class="size-5 shrink-0" /> {gettext(
                    "Contact"
                  )}
                </.link>
                <.link
                  id="m-logout"
                  href={~p"/users/log-out"}
                  method="delete"
                  class="flex min-h-10 sm:min-h-9 items-center gap-x-3 rounded-button px-3 py-2 text-base font-medium text-on-sidebar/80 hover:bg-on-sidebar/10 hover:text-on-sidebar focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-on-sidebar"
                >
                  <.icon name="hero-arrow-right-start-on-rectangle" class="size-5 shrink-0" /> {gettext(
                    "Log out"
                  )}
                </.link>
              </div>
            </div>
          </el-disclosure>
        </nav>
      </div>

      <%!-- Laptop: the menu is on a bar at the top of the page --%>
      <div class="flex grow flex-col">
        <header class="sticky top-0 z-40 hidden h-16 shrink-0 items-center gap-x-4 border-b border-line bg-surface px-8 lg:flex">
          <.wordmark id="logo" navigate={~p"/dashboard"} />
          <nav aria-label={gettext("Main")} class="ml-2 flex min-w-0 items-center gap-x-1">
            <.link
              id="nav-dashboard"
              navigate={~p"/dashboard"}
              aria-current={@active == :dashboard && "page"}
              class={top_nav_class()}
            >
              <.icon name="hero-squares-2x2" class="size-5 shrink-0" />{gettext("Dashboard")}
            </.link>
            <.link
              id="nav-history"
              navigate={~p"/history"}
              aria-current={@active == :history && "page"}
              class={top_nav_class()}
            >
              <.icon name="hero-document-text" class="size-5 shrink-0" />{gettext("Documents")}
            </.link>
            <%!-- What the user keeps to use again: one menu, so the bar stays short --%>
            <.top_menu
              id="nav-library"
              label={gettext("Library")}
              icon="hero-archive-box"
              current={@active in [:businesses, :signatures, :stamps]}
              items={[
                %{
                  id: "nav-businesses",
                  label: gettext("Saved businesses"),
                  icon: "hero-building-storefront",
                  path: ~p"/businesses",
                  current: @active == :businesses
                },
                %{
                  id: "nav-signatures",
                  label: gettext("Signatures"),
                  icon: "hero-pencil",
                  path: ~p"/signatures",
                  current: @active == :signatures
                },
                %{
                  id: "nav-stamps",
                  label: gettext("Stamps"),
                  icon: "hero-ticket",
                  path: ~p"/stamps",
                  current: @active == :stamps
                }
              ]}
            />
            <%!-- Help: the contact form, and for an admin the messages that come in --%>
            <.top_menu
              :if={@admin? and @contact?}
              id="nav-help"
              label={gettext("Help")}
              icon="hero-lifebuoy"
              current={@active in [:contact, :messages]}
              items={[
                %{
                  id: "nav-contact",
                  label: gettext("Contact"),
                  icon: "hero-chat-bubble-left-right",
                  path: ~p"/contact",
                  current: @active == :contact
                },
                %{
                  id: "nav-messages",
                  label: gettext("Messages"),
                  icon: "hero-inbox",
                  path: ~p"/admin/messages",
                  current: @active == :messages
                }
              ]}
            />
            <.link
              :if={@contact? and not @admin?}
              id="nav-contact"
              navigate={~p"/contact"}
              aria-current={@active == :contact && "page"}
              class={top_nav_class()}
            >
              <.icon name="hero-chat-bubble-left-right" class="size-5 shrink-0" />{gettext("Contact")}
            </.link>
            <.link
              :if={@admin? and not @contact?}
              id="nav-messages"
              navigate={~p"/admin/messages"}
              aria-current={@active == :messages && "page"}
              class={top_nav_class()}
            >
              <.icon name="hero-inbox" class="size-5 shrink-0" />{gettext("Messages")}
            </.link>
          </nav>
          <div class="ml-auto flex shrink-0 items-center gap-x-3">
            <.button id="new-document" navigate={home_path(@locale)} title={gettext("New document")}>
              <.icon name="hero-plus" class="size-5" />
              <span class="hidden xl:inline">{gettext("New document")}</span>
              <span class="sr-only xl:hidden">{gettext("New document")}</span>
            </.button>
            <.locale_menu id="locale-menu" locale={@locale} compact />
            <.theme_menu id="theme-menu" />
            <div aria-hidden="true" class="h-6 w-px bg-line"></div>
            <.user_menu id="user-menu" user={@user} />
          </div>
        </header>

        <main class="grow">
          <div :if={@title} class="border-b border-line bg-surface lg:border-0 lg:bg-transparent">
            <div class="mx-auto max-w-8xl px-4 py-4 sm:px-6 lg:px-8 lg:pt-5 lg:pb-0">
              <div class="sm:flex sm:items-center sm:justify-between sm:gap-x-6">
                <div>
                  <h1 class="font-display text-2xl/8 font-semibold tracking-tight text-ink">
                    {@title}
                  </h1>
                  <p :if={@subtitle} class="mt-1 text-sm/6 text-ink-muted">{@subtitle}</p>
                </div>
                <div :if={@actions != []} class="mt-4 flex gap-x-3 sm:mt-0 sm:shrink-0">
                  {render_slot(@actions)}
                </div>
              </div>
            </div>
          </div>
          <div class="mx-auto max-w-8xl px-4 py-4 sm:px-6 lg:px-8 lg:py-5">
            {render_slot(@inner_block)}
          </div>
        </main>

        <.site_footer locale={@locale} />
      </div>
    </div>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.

  The messages sit in a fixed live region at the top right, so a screen reader reads each
  new one aloud and nothing on the page moves.

  ## Examples

      <.flash_group flash={@flash} />
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div
      id={@id}
      aria-live="polite"
      class="pointer-events-none fixed inset-x-0 top-0 z-60 flex flex-col items-end gap-3 p-4 sm:p-6"
    >
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title={gettext("We can't find the internet")}
        phx-disconnected={
          show(".phx-client-error #client-error")
          |> JS.remove_attribute("hidden", to: ".phx-client-error #client-error")
        }
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title={gettext("Something went wrong!")}
        phx-disconnected={
          show(".phx-server-error #server-error")
          |> JS.remove_attribute("hidden", to: ".phx-server-error #server-error")
        }
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        {gettext("Attempting to reconnect")}
        <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
      </.flash>
    </div>
    """
  end
end
