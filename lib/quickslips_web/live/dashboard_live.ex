defmodule QuickSlipsWeb.DashboardLive do
  use QuickSlipsWeb, :live_view

  import QuickSlipsWeb.CatalogueComponents, only: [template_tile: 1]

  alias QuickSlipsWeb.SampleTemplates

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Dashboard")
     |> assign(:quick_start, Enum.take(SampleTemplates.list(), 4))}
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
        <%!-- The figures are zero until the features behind them exist (credits: Milestone 9,
             documents: Milestone 8, saved businesses: Milestone 8). --%>
        <dl class="grid grid-cols-2 gap-4 sm:grid-cols-3">
          <.stat class="col-span-2 sm:col-span-1" label="Credits" value="0" icon="hero-banknotes" />
          <.stat label="Documents this month" value="0" icon="hero-document-text" />
          <.stat label="Saved businesses" value="0" icon="hero-building-storefront" />
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
          <h2 id="recent-title" class="sr-only">Recent documents</h2>
          <.empty_state icon="hero-document-text" title="No documents yet">
            Documents you download while logged in are kept here, so you can download them again later.
            <:actions>
              <.button id="empty-new-document" navigate={~p"/"}>
                <.icon name="hero-plus" class="size-5" /> New document
              </.button>
            </:actions>
          </.empty_state>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp first_name(user) do
    (user.name || user.email) |> String.split(~r/[\s@]/, trim: true) |> List.first()
  end
end
