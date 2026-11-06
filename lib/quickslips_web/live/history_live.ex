defmodule QuickSlipsWeb.HistoryLive do
  use QuickSlipsWeb, :live_view

  # A live navigation does not run the router's plugs, so the login is checked here too.
  on_mount {QuickSlipsWeb.UserAuth, :require_authenticated}

  import QuickSlipsWeb.CatalogueComponents, only: [search_input: 1]

  alias QuickSlips.Documents
  alias QuickSlips.Documents.Document
  alias QuickSlips.Locales
  alias QuickSlips.Templates

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Documents.subscribe_documents(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(:page_title, "Documents")
     |> assign(:query, "")
     # slug -> the icon of its template, for the tile of each row
     |> assign(:icons, Map.new(Templates.list(), &{&1["slug"], &1["icon"]}))
     |> load_documents()}
  end

  @impl true
  def handle_event("search", %{"q" => query}, socket) do
    {:noreply, socket |> assign(:query, query) |> load_documents()}
  end

  def handle_event("delete", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope
    document = Documents.get_document!(scope, id)
    {:ok, _document} = Documents.delete_document(scope, document)
    {:noreply, load_documents(socket)}
  end

  # A document was made, or deleted, in another tab.
  @impl true
  def handle_info({type, %Document{}}, socket) when type in [:created, :updated, :deleted] do
    {:noreply, load_documents(socket)}
  end

  # Fetch the list again and put it in the stream. `empty?` is kept apart, because a stream can't be asked
  # whether it is empty.
  defp load_documents(socket) do
    documents =
      Documents.list_documents(socket.assigns.current_scope, search: socket.assigns.query)

    socket
    |> assign(:empty?, documents == [])
    |> stream(:documents, documents, reset: true)
  end

  defp icon(icons, slug), do: icons[slug] || "hero-document-text"

  # The page of the template in the language the document was made in, with the document to start from. A
  # template that is not (any more) in that language opens in the default one.
  defp edit_path(doc) do
    locale = Locales.for_document(doc.language, doc.options)

    path =
      Templates.public_path(doc.slug, locale) ||
        Templates.public_path(doc.slug, Locales.default())

    if path, do: path <> "?" <> URI.encode_query(from: doc.id), else: ~p"/"
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app
      flash={@flash}
      current_scope={@current_scope}
      locale={@locale}
      active={:history}
      title="Documents"
      subtitle="Everything you have downloaded. Download it again, change it or delete it."
    >
      <:actions>
        <.button id="history-new-document" navigate={home_path(@locale)}>
          <.icon name="hero-plus" class="size-5" /> New document
        </.button>
      </:actions>

      <div id="history">
        <form id="history-search-form" phx-change="search" phx-submit="search" class="lg:max-w-sm">
          <.search_input
            id="history-search"
            value={@query}
            label="Search documents"
            placeholder="Search documents"
          />
        </form>

        <.empty_state
          :if={@empty? and @query == ""}
          icon="hero-document-text"
          title="No documents yet"
        >
          Documents you download while logged in are kept here, so you can download them again later.
          <:actions>
            <.button id="history-empty-new-document" navigate={home_path(@locale)}>
              <.icon name="hero-plus" class="size-5" /> New document
            </.button>
          </:actions>
        </.empty_state>
        <p :if={@empty? and @query != ""} id="history-no-match" class="mt-6 text-sm/6 text-ink-muted">
          No document matches your search.
        </p>

        <ul
          id="documents"
          phx-update="stream"
          role="list"
          class={[
            "mt-6 divide-y divide-line overflow-hidden rounded-card border border-line bg-surface shadow-card",
            @empty? && "hidden"
          ]}
        >
          <li
            :for={{id, doc} <- @streams.documents}
            id={id}
            class="flex items-center gap-x-4 px-4 py-3 sm:px-6"
          >
            <span
              class="flex size-10 shrink-0 items-center justify-center rounded-field bg-primary-soft text-primary"
              aria-hidden="true"
            >
              <.icon name={icon(@icons, doc.slug)} class="size-5" />
            </span>
            <div class="min-w-0 grow">
              <p class="truncate text-sm/6 font-semibold text-ink">{doc.title}</p>
              <p class="truncate text-xs/5 text-ink-muted">
                Downloaded {Calendar.strftime(doc.inserted_at, "%d %b %Y")}
              </p>
            </div>
            <div class="flex shrink-0 gap-x-1">
              <.link
                id={"download-#{doc.id}"}
                href={~p"/history/#{doc.id}/download"}
                title="Download again"
                class="inline-flex size-11 items-center justify-center rounded-button text-ink-muted hover:bg-surface-muted hover:text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus sm:size-9 pointer-coarse:size-11"
              >
                <span class="sr-only">Download again</span>
                <.icon name="hero-arrow-down-tray" class="size-5" />
              </.link>
              <.link
                id={"edit-#{doc.id}"}
                navigate={edit_path(doc)}
                title="Edit and regenerate"
                class="inline-flex size-11 items-center justify-center rounded-button text-ink-muted hover:bg-surface-muted hover:text-ink focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus sm:size-9 pointer-coarse:size-11"
              >
                <span class="sr-only">Edit and regenerate</span>
                <.icon name="hero-pencil-square" class="size-5" />
              </.link>
              <button
                id={"delete-#{doc.id}"}
                type="button"
                phx-click="delete"
                phx-value-id={doc.id}
                data-confirm="Delete this document? It can't be brought back."
                title="Delete"
                class="inline-flex size-11 items-center justify-center rounded-button text-ink-muted hover:bg-danger-soft hover:text-danger focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus sm:size-9 pointer-coarse:size-11"
              >
                <span class="sr-only">Delete</span>
                <.icon name="hero-trash" class="size-5" />
              </button>
            </div>
          </li>
        </ul>
      </div>
    </Layouts.app>
    """
  end
end
