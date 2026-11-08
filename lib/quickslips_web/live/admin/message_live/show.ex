defmodule QuickSlipsWeb.Admin.MessageLive.Show do
  @moduledoc """
  `/admin/messages/:id`: one message of the contact form, for the owner: what was written, who wrote it, which page
  it is about, whether the e-mails about it went out, and what to do with it. Opening a message that is new marks it
  as read (it can be marked as unread again); the owner can say it is resolved, answer it from their mail program
  (the Reply button opens a message to the sender with the reference in the subject), or delete it for good, which is
  also how a sender's request to be forgotten is met.

  The page follows the message: the two e-mails go out a moment after it is kept, and the page shows them as they
  are sent.
  """
  use QuickSlipsWeb, :live_view

  # A live navigation does not run the router's plugs, so the admin is checked here too.
  on_mount {QuickSlipsWeb.UserAuth, :require_admin}

  import QuickSlipsWeb.Admin.MessageComponents

  alias QuickSlips.Contact
  alias QuickSlips.Contact.Message
  alias QuickSlips.Contact.Topic

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    scope = socket.assigns.current_scope
    message = Contact.get_message!(scope, id)

    if connected?(socket), do: Contact.subscribe_messages(scope)

    {:ok,
     socket
     |> assign(:page_title, "Message #{message.reference}")
     |> assign(:message, opened(scope, message))}
  end

  # Opening a new message is reading it.
  defp opened(scope, %Message{status: :new} = message) do
    {:ok, message} = Contact.set_status(scope, message, :read)
    message
  end

  defp opened(_scope, message), do: message

  @impl true
  def handle_event("status", %{"status" => status}, socket) do
    # a word that is not a status is ignored: the event can be sent by anything that speaks to the page
    case Enum.find(Message.statuses(), &(Atom.to_string(&1) == status)) do
      nil ->
        {:noreply, socket}

      status ->
        {:ok, message} =
          Contact.set_status(socket.assigns.current_scope, socket.assigns.message, status)

        {:noreply, assign(socket, :message, message)}
    end
  end

  def handle_event("delete", _params, socket) do
    {:ok, _message} = Contact.delete_message(socket.assigns.current_scope, socket.assigns.message)

    {:noreply,
     socket
     |> put_flash(:info, "The message was deleted.")
     |> push_navigate(to: ~p"/admin/messages")}
  end

  @impl true
  def handle_info(
        {:updated, %Message{id: id} = changed},
        %{assigns: %{message: %{id: id} = message}} = socket
      ) do
    # the account was loaded once, and is not part of what changes
    {:noreply, assign(socket, :message, %{changed | user: message.user})}
  end

  def handle_info({:deleted, %Message{id: id}}, %{assigns: %{message: %{id: id}}} = socket) do
    {:noreply,
     socket
     |> put_flash(:info, "The message was deleted.")
     |> push_navigate(to: ~p"/admin/messages")}
  end

  def handle_info({_event, %Message{}}, socket), do: {:noreply, socket}

  ## The page

  # A message to the sender, with the reference in the subject, in the owner's own mail program.
  defp reply_link(%Message{email: email, reference: reference}) do
    subject = URI.encode("Re: Your message to QuickSlips (#{reference})", &URI.char_unreserved?/1)
    "mailto:#{email}?subject=#{subject}"
  end

  # The statuses that a message can move to from where it is.
  defp moves(%Message{status: status}) do
    [
      {:new, "Mark as unread", "hero-envelope"},
      {:read, "Mark as read", "hero-envelope-open"},
      {:resolved, "Mark as resolved", "hero-check-circle"}
    ]
    |> Enum.reject(fn {to, _label, _icon} -> to == status end)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale} active={:messages}>
      <.header>
        Message <span class="font-mono">{@message.reference}</span>
        <:subtitle>
          <span id="message-subtitle">
            {Topic.name(@message.topic)}, received {time(@message.inserted_at)}
          </span>
        </:subtitle>
      </.header>

      <div class="mb-6 flex flex-wrap gap-2">
        <.button id="back-to-messages" navigate={~p"/admin/messages"}>
          <.icon name="hero-arrow-left" /> All messages
        </.button>
        <.button id="reply-link" variant="primary" href={reply_link(@message)}>
          <.icon name="hero-arrow-uturn-left" /> Reply
        </.button>
      </div>

      <div class="grid gap-6 lg:grid-cols-3">
        <div class="lg:col-span-2">
          <.card>
            <:header>
              <h2 class="text-base/6 font-semibold text-ink">Message</h2>
            </:header>
            <%!-- Written on one line: the words keep their line breaks (pre-wrap), so the source must not add any. --%>
            <p
              id="message-body"
              class="text-base/7 break-words whitespace-pre-wrap text-ink"
              phx-no-format
            >{@message.message}</p>
          </.card>
        </div>

        <div class="space-y-6">
          <.card>
            <:header>
              <h2 class="text-base/6 font-semibold text-ink">Status</h2>
            </:header>
            <div class="flex items-center gap-x-3">
              <span id="message-status"><.status_badge status={@message.status} /></span>
            </div>
            <div class="mt-4 flex flex-wrap gap-2">
              <.button
                :for={{status, label, icon} <- moves(@message)}
                id={"move-to-#{status}"}
                type="button"
                variant="secondary"
                size="sm"
                phx-click="status"
                phx-value-status={status}
              >
                <.icon name={icon} class="size-4" /> {label}
              </.button>
            </div>
          </.card>

          <.card>
            <:header>
              <h2 class="text-base/6 font-semibold text-ink">Details</h2>
            </:header>
            <dl class="space-y-4 text-sm/6">
              <div>
                <dt class="font-medium text-ink-muted">From</dt>
                <dd id="message-from" class="text-ink">
                  <span :if={@message.name}>{@message.name}<br /></span>
                  <a href={"mailto:" <> @message.email} class="text-primary hover:underline">
                    {@message.email}
                  </a>
                </dd>
              </div>
              <div :if={@message.user}>
                <dt class="font-medium text-ink-muted">Account</dt>
                <dd id="message-account" class="text-ink">
                  {@message.user.email} (user {@message.user.id})
                </dd>
              </div>
              <div :if={@message.locale}>
                <dt class="font-medium text-ink-muted">Language and country of the page</dt>
                <dd id="message-locale" class="text-ink">{@message.locale}</dd>
              </div>
              <div :if={@message.page}>
                <dt class="font-medium text-ink-muted">About this page</dt>
                <dd id="message-page" class="break-all text-ink">
                  <.link href={@message.page} class="text-primary hover:underline">
                    {@message.page}
                  </.link>
                </dd>
              </div>
              <div>
                <dt class="font-medium text-ink-muted">E-mail to you</dt>
                <dd id="message-owner-notified" class="text-ink">
                  <%= if @message.owner_notified_at do %>
                    Sent {time(@message.owner_notified_at)}
                  <% else %>
                    <.badge tone={:warning}>Not sent</.badge>
                    <span class="text-ink-muted">Not yet, or the mail provider refused it.</span>
                  <% end %>
                </dd>
              </div>
              <div>
                <dt class="font-medium text-ink-muted">Confirmation to the sender</dt>
                <dd id="message-confirmation" class="text-ink">
                  <%= if @message.confirmation_sent_at do %>
                    Sent {time(@message.confirmation_sent_at)}
                  <% else %>
                    <.badge tone={:warning}>Not sent</.badge>
                    <span class="text-ink-muted">
                      Not yet, or the mail provider refused it, or the address had its share for today.
                    </span>
                  <% end %>
                </dd>
              </div>
            </dl>
          </.card>

          <.button
            id="delete-message"
            type="button"
            variant="ghost-danger"
            phx-click="delete"
            data-confirm="Delete this message for good? This cannot be undone."
          >
            <.icon name="hero-trash" class="size-5" /> Delete message
          </.button>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
