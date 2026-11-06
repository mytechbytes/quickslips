defmodule QuickSlipsWeb.DashboardLive do
  use QuickSlipsWeb, :live_view

  import QuickSlipsWeb.CatalogueComponents, only: [template_tile: 1]

  alias QuickSlips.Businesses
  alias QuickSlips.Documents
  alias QuickSlips.Templates

  # The four tiles of "Start a new document": the bills people make most often.
  @quick_start ~w(fuel-bill rent-receipt taxi-receipt restaurant-bill)

  @impl true
  def mount(_params, _session, socket) do
    scope = socket.assigns.current_scope

    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:quick_start, quick_start())
     |> assign(:documents_this_month, Documents.count_this_month(scope))
     |> assign(:business_count, Businesses.count_businesses(scope))
     |> assign(:recent, Documents.list_documents(scope, limit: 5))}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      active={:dashboard}
      title="Dashboard"
      subtitle={"Welcome back, #{first_name(@current_scope.user)}."}
    >
      <:actions>
        <.button id="dashboard-new-document" navigate={~p"/"}>
          <.icon name="hero-plus" class="size-5" /> New document
        </.button>
      </:actions>

      <div id="dashboard">
        <%!-- Credits stay at zero until Milestone 9 builds the credit ledger. --%>
        <dl class="grid grid-cols-2 gap-4 sm:grid-cols-3">
          <.stat class="col-span-2 sm:col-span-1" label="Credits" value="0" icon="hero-banknotes" />
          <.stat
            id="stat-documents"
            label="Documents this month"
            value={Integer.to_string(@documents_this_month)}
            icon="hero-document-text"
          />
          <.stat
            id="stat-businesses"
            label="Saved businesses"
            value={Integer.to_string(@business_count)}
            icon="hero-building-storefront"
          />
        </dl>

        <section aria-labelledby="quick-title" class="mt-8">
          <h2 id="quick-title" class="text-base/7 font-semibold text-ink">Start a new document</h2>
          <p class="mt-1 text-sm/6 text-ink-muted">
            Pick a template. A saved business fills in the seller for you.
          </p>
          <ul role="list" class="mt-4 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
            <li :for={template <- @quick_start} id={"quick-#{template["slug"]}"}>
              <.template_tile template={template} class="flex gap-4 sm:flex-col sm:gap-3" />
            </li>
          </ul>
        </section>

        <section aria-labelledby="recent-title" class="mt-8">
          <div class="flex items-baseline justify-between gap-4">
            <h2 id="recent-title" class="text-base/7 font-semibold text-ink">Recent documents</h2>
            <.link
              :if={@recent != []}
              id="all-documents"
              navigate={~p"/history"}
              class="text-sm/6 font-medium text-primary hover:underline"
            >
              See all
            </.link>
          </div>
          <div :if={@recent == []} id="recent-empty" class="mt-4">
            <.empty_state icon="hero-document-text" title="No documents yet">
              Documents you download while logged in are kept here, so you can download them again later.
              <:actions>
                <.button id="empty-new-document" navigate={~p"/"}>
                  <.icon name="hero-plus" class="size-5" /> New document
                </.button>
              </:actions>
            </.empty_state>
          </div>
          <ul
            :if={@recent != []}
            id="recent-documents"
            role="list"
            class="mt-4 divide-y divide-line overflow-hidden rounded-card border border-line bg-surface shadow-card"
          >
            <li
              :for={doc <- @recent}
              id={"recent-#{doc.id}"}
              class="flex items-center justify-between gap-x-4 px-4 py-3 sm:px-6"
            >
              <div class="min-w-0">
                <p class="truncate text-sm/6 font-semibold text-ink">{doc.title}</p>
                <p class="truncate text-xs/5 text-ink-muted">
                  Downloaded {Calendar.strftime(doc.inserted_at, "%d %b %Y")}
                </p>
              </div>
              <.link
                id={"recent-download-#{doc.id}"}
                href={~p"/history/#{doc.id}/download"}
                class="inline-flex shrink-0 items-center gap-1.5 text-sm/6 font-medium text-primary hover:underline"
              >
                <.icon name="hero-arrow-down-tray" class="size-4" /> Download again
              </.link>
            </li>
          </ul>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp quick_start do
    for slug <- @quick_start, {:ok, schema} <- [Templates.get(slug)], do: schema
  end

  defp first_name(user) do
    (user.name || user.email) |> String.split(~r/[\s@]/, trim: true) |> List.first()
  end
end
