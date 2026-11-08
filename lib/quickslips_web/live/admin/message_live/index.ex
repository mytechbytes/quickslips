defmodule QuickSlipsWeb.Admin.MessageLive.Index do
  @moduledoc """
  `/admin/messages`: what visitors wrote in the contact form, newest first, for the owner (the people in
  `ADMIN_EMAILS`). It can show the messages of one status or one kind, or the ones that have a word in them (the
  reference that the sender was given, an address, a name, or words of the message), a page at a time.

  The filters are in the address (`?status=new&topic=problem&q=gst&page=2`), so a search can be kept, shared with
  another admin and reached with the Back button. The page follows the messages as they arrive and change.
  """
  use QuickSlipsWeb, :live_view

  # A live navigation does not run the router's plugs, so the admin is checked here too.
  on_mount {QuickSlipsWeb.UserAuth, :require_admin}

  import QuickSlipsWeb.Admin.MessageComponents

  alias QuickSlips.Contact
  alias QuickSlips.Contact.Message
  alias QuickSlips.Contact.Topic

  @per_page 25

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Contact.subscribe_messages(socket.assigns.current_scope)

    {:ok, assign(socket, :page_title, "Messages")}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    filters = %{
      status: pick(params["status"], Message.statuses()),
      topic: pick(params["topic"], Message.topics()),
      search: search(params["q"]),
      page: page(params["page"])
    }

    {:noreply, socket |> assign(:filters, filters) |> load()}
  end

  @impl true
  def handle_event("filter", %{"filters" => %{"q" => q, "topic" => topic}}, socket) do
    filters = %{
      socket.assigns.filters
      | search: search(q),
        topic: pick(topic, Message.topics()),
        page: 1
    }

    {:noreply, push_patch(socket, to: filter_path(filters))}
  end

  @impl true
  def handle_info({event, %Message{}}, socket) when event in [:created, :updated, :deleted] do
    {:noreply, load(socket)}
  end

  ## What the address says

  # One of the known words, or nothing: the address is typed by anybody who can type an address.
  defp pick(value, allowed), do: Enum.find(allowed, &(Atom.to_string(&1) == value))

  defp search(value) when is_binary(value) do
    case value |> String.trim() |> String.slice(0, 100) do
      "" -> nil
      term -> term
    end
  end

  defp search(_none), do: nil

  defp page(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} when number > 0 -> number
      _not_a_page -> 1
    end
  end

  defp page(_none), do: 1

  # The address of this page with these filters: only what is set is in it.
  defp filter_path(filters, changes \\ []) do
    filters = Map.merge(filters, Map.new(changes))

    query =
      for {key, value} <- [
            status: filters.status,
            topic: filters.topic,
            q: filters.search,
            page: if(filters.page > 1, do: filters.page)
          ],
          value != nil,
          do: {key, value}

    ~p"/admin/messages?#{query}"
  end

  defp load(socket) do
    scope = socket.assigns.current_scope
    filters = socket.assigns.filters

    %{messages: messages, total: total, page: page, pages: pages} =
      Contact.list_messages(scope,
        status: filters.status,
        topic: filters.topic,
        search: filters.search,
        page: filters.page,
        per_page: @per_page
      )

    socket
    |> assign(
      total: total,
      page: page,
      pages: pages,
      counts: Contact.count_messages(scope),
      filter_form:
        to_form(%{"q" => filters.search || "", "topic" => to_string(filters.topic || "")},
          as: :filters
        )
    )
    |> stream(:messages, messages, reset: true)
  end

  ## The page

  defp status_chips do
    [{nil, :all, "All"}] ++ for status <- Message.statuses(), do: {status, status, label(status)}
  end

  defp label(status), do: status_label(status)

  defp topic_options, do: for(topic <- Message.topics(), do: {Topic.name(topic), topic})

  # The start of a message, on one line.
  defp excerpt(text) do
    line = text |> String.replace(~r/\s+/u, " ") |> String.trim()

    case String.split_at(line, 110) do
      {short, ""} -> short
      {short, _more} -> String.trim_trailing(short) <> "…"
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale} active={:messages}>
      <.header>
        Messages
        <:subtitle>
          What visitors wrote in the contact form. Open one to read it, answer it, or mark it as dealt with.
        </:subtitle>
      </.header>

      <nav id="message-status" aria-label="Status" class="mb-4 flex flex-wrap gap-2">
        <.link
          :for={{status, key, label} <- status_chips()}
          id={"status-#{key}"}
          patch={filter_path(@filters, status: status, page: 1)}
          aria-current={@filters.status == status && "page"}
          class={[
            "inline-flex items-center gap-x-2 rounded-full px-3 py-1.5 text-sm/5 font-medium ring-1 ring-inset transition-colors motion-reduce:transition-none",
            "bg-surface text-ink-muted ring-line hover:text-ink hover:ring-line-strong",
            "aria-[current=page]:bg-primary-soft aria-[current=page]:text-primary aria-[current=page]:ring-primary/30",
            "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
          ]}
        >
          {label}
          <span class="tabular-nums opacity-80">{@counts[key]}</span>
        </.link>
      </nav>

      <.form
        for={@filter_form}
        id="message-filters"
        phx-change="filter"
        phx-submit="filter"
        class="mb-6 grid gap-x-4 sm:grid-cols-[minmax(0,1fr)_14rem]"
      >
        <.input
          field={@filter_form[:q]}
          type="search"
          id="message-search"
          placeholder="Reference, e-mail, name or words"
          aria-label="Search messages"
          autocomplete="off"
          phx-debounce="300"
        />
        <.input
          field={@filter_form[:topic]}
          type="select"
          id="message-topic"
          prompt="All kinds"
          options={topic_options()}
        />
      </.form>

      <div :if={@total == 0} id="messages-empty">
        <.empty_state icon="hero-inbox" title="No messages">
          <%= if @filters.status || @filters.topic || @filters.search do %>
            Nothing matches these filters.
          <% else %>
            When someone writes to you from the contact form, it is kept here.
          <% end %>
        </.empty_state>
      </div>

      <%!-- A list and not a table: on a phone a row stacks, and the whole row is one link (the sender's name). --%>
      <ul
        :if={@total > 0}
        id="messages"
        phx-update="stream"
        class="divide-y divide-line overflow-hidden rounded-card border border-line bg-surface shadow-card"
      >
        <li
          :for={{id, message} <- @streams.messages}
          id={id}
          class="relative flex flex-col gap-y-2 px-4 py-4 transition-colors hover:bg-surface-muted motion-reduce:transition-none sm:flex-row sm:items-start sm:justify-between sm:gap-x-6 sm:px-6"
        >
          <div class="min-w-0 flex-auto">
            <div class="flex flex-wrap items-center gap-x-2 gap-y-1">
              <.status_badge status={message.status} />
              <.link
                navigate={~p"/admin/messages/#{message}"}
                class={[
                  "max-w-full truncate rounded-field text-sm/6 text-ink after:absolute after:inset-0",
                  "focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus",
                  message.status == :new && "font-semibold"
                ]}
              >
                {message.name || message.email}
              </.link>
              <span :if={message.name} class="max-w-full truncate text-sm/6 text-ink-muted">
                {message.email}
              </span>
            </div>
            <p class={[
              "mt-1 line-clamp-2 text-sm/6 break-words",
              (message.status == :new && "text-ink") || "text-ink-muted"
            ]}>
              {excerpt(message.message)}
            </p>
            <div class="mt-2 flex flex-wrap items-center gap-x-2 gap-y-1">
              <.topic_badge topic={message.topic} />
              <span class="font-mono text-xs text-ink-muted">{message.reference}</span>
            </div>
          </div>
          <time
            datetime={DateTime.to_iso8601(message.inserted_at)}
            class="text-xs/5 text-ink-muted sm:shrink-0 sm:text-right sm:text-sm/6"
          >
            {time(message.inserted_at)}
          </time>
        </li>
      </ul>

      <nav
        :if={@pages > 1}
        id="message-pages"
        aria-label="Pages"
        class="mt-4 flex items-center justify-between gap-x-4"
      >
        <p class="text-sm/6 text-ink-muted">Page {@page} of {@pages}, {@total} messages</p>
        <div class="flex gap-x-2">
          <.button
            :if={@page > 1}
            id="newer-messages"
            variant="secondary"
            size="sm"
            patch={filter_path(@filters, page: @page - 1)}
          >
            Newer
          </.button>
          <.button
            :if={@page < @pages}
            id="older-messages"
            variant="secondary"
            size="sm"
            patch={filter_path(@filters, page: @page + 1)}
          >
            Older
          </.button>
        </div>
      </nav>
    </Layouts.app>
    """
  end
end
