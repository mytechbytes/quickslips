defmodule QuickSlipsWeb.SitemapLive do
  @moduledoc """
  `/sitemap`: every public page of the site, for people: by language and country, then by kind of bill, each page
  named in the language of its locale. They are the pages of the XML sitemap (`/sitemap.xml`), which is what search
  engines read; a browser may draw that one nicely too (an XSLT stylesheet), but browsers are removing XSLT, and
  this page works in all of them.

  It is a LiveView of the `:current_user` live session like every public page, so that a click on the footer's
  link is a live navigation.
  """
  use QuickSlipsWeb, :live_view

  alias QuickSlipsWeb.Sitemap

  @impl true
  def mount(_params, _session, socket) do
    groups = Sitemap.groups()

    {:ok,
     assign(socket,
       page_title: gettext("Sitemap"),
       groups: groups,
       page_count: groups |> Enum.map(& &1.count) |> Enum.sum()
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale}>
      <article id="sitemap-page" class="mx-auto max-w-5xl py-8">
        <h1 class="font-display text-2xl font-bold tracking-tight text-ink">{gettext("Sitemap")}</h1>
        <p class="mt-1 text-sm/6 text-ink-muted">
          {gettext("Every page of QuickSlips, by language and country.")}
        </p>

        <div id="sitemap-summary" class="mt-5 flex flex-wrap items-center gap-x-3 gap-y-2 text-sm/6">
          <span class="rounded-full bg-primary-soft px-3 py-1 font-medium text-ink">
            {gettext("Pages: %{count}", count: @page_count)}
          </span>
          <span class="rounded-full bg-primary-soft px-3 py-1 font-medium text-ink">
            {gettext("Languages and countries: %{count}", count: length(@groups))}
          </span>
          <span class="text-ink-muted">
            {gettext("The same list, as search engines read it:")}
            <.link
              id="sitemap-xml-link"
              href={~p"/sitemap.xml"}
              class="rounded-field font-medium text-primary hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
            >
              sitemap.xml
            </.link>
          </span>
        </div>

        <%!-- The group of the visitor's own locale is open; the others are one click away. --%>
        <div class="mt-6 space-y-3">
          <details
            :for={group <- @groups}
            id={"sitemap-#{group.locale.code}"}
            open={group.locale.code == @locale.code}
            class="group rounded-card border border-line bg-surface shadow-card"
          >
            <summary class="flex cursor-pointer list-none items-center gap-x-3 rounded-card px-4 py-3 hover:bg-surface-muted focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus [&::-webkit-details-marker]:hidden">
              <.icon
                name="hero-chevron-right"
                class="size-4 shrink-0 text-ink-muted motion-safe:transition motion-safe:duration-150 group-open:rotate-90"
              />
              <span class="font-semibold text-ink" lang={group.locale.language}>
                {group.locale.name}
              </span>
              <span class="text-sm/6 text-ink-muted">· {country_name(group.locale.country)}</span>
              <span class="ml-auto rounded-full bg-surface-muted px-2.5 py-0.5 text-xs font-medium text-ink-muted">
                {group.count}
              </span>
            </summary>
            <div class="border-t border-line px-4 pt-3 pb-4" lang={group.locale.language}>
              <.link
                navigate={group.home}
                class="inline-flex items-center gap-x-1 rounded-field text-sm/6 font-medium text-primary hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
              >
                <.icon name="hero-squares-2x2" class="size-4" /> {group.home}
              </.link>
              <section :for={category <- group.categories} class="mt-4">
                <h2 class="text-xs font-semibold tracking-wide text-ink-muted uppercase">
                  {category.name}
                </h2>
                <ul class="mt-2 grid gap-x-6 gap-y-1.5 sm:grid-cols-2 lg:grid-cols-3">
                  <li :for={bill <- category.bills}>
                    <.link
                      navigate={bill.path}
                      class="rounded-field text-sm/6 text-ink hover:text-primary hover:underline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
                    >
                      {bill.name}
                    </.link>
                  </li>
                </ul>
              </section>
            </div>
          </details>
        </div>
      </article>
    </Layouts.app>
    """
  end
end
