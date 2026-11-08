defmodule QuickSlipsWeb.ContactLive do
  @moduledoc """
  `/contact`: where a visitor writes to the owner of the site to ask for a change, give feedback, report a problem
  or raise a complaint or dispute. The message is kept and the owner is told by e-mail, and the sender gets a
  confirmation (`QuickSlips.Contact`).

  It is a public page of the `:current_user` live session like the others, so a visitor and a logged-in user both
  reach it with a live navigation, and it sits above `/:locale` in the router. It speaks the language of the
  visitor, unlike the legal pages.

  `?topic=change` preselects a kind of message, and `?about=/en-in/fuel-bill-generator` says which page the visitor
  comes from; the bill pages link here with both. The address is a note for the owner and nothing more, so only a
  short path of this site is taken.

  Everybody passes the Turnstile check, a user as well as a visitor: the confirmation goes to the address that was
  typed, which anybody could have typed, and an account does not make it theirs. The `ContactTurnstile` hook (see
  `assets/js/contact.ts`) draws the widget and tells the server each token it gets; the server keeps the last one
  and asks Cloudflare about it when the form is sent.
  """
  use QuickSlipsWeb, :live_view

  alias QuickSlips.Contact
  alias QuickSlips.Contact.Message
  alias QuickSlips.Contact.Topic
  alias QuickSlips.Site
  alias QuickSlips.Turnstile
  alias QuickSlipsWeb.Endpoint

  # A path of this site: a slash, then a name that does not start with another slash (that would be a way to
  # another site), made of letters, digits and a few signs.
  @about ~r|\A/[A-Za-z0-9_.-][A-Za-z0-9/_.-]{0,159}\z|

  @impl true
  def mount(params, _session, socket) do
    user = signed_in_user(socket.assigns.current_scope)

    {:ok,
     socket
     |> assign(
       page_title: gettext("Contact"),
       contact_email: Site.contact_email(),
       user: user,
       about: about(params["about"]),
       status: if(Contact.available?(), do: :writing, else: :unavailable),
       sent: nil,
       error: nil,
       turnstile_site_key: turnstile_site_key(),
       turnstile_token: nil
     )
     |> assign_form(Contact.change_message(blank(user, topic(params["topic"]))))}
  end

  @impl true
  def handle_event("validate", %{"contact" => params}, socket) do
    changeset = %Message{} |> Contact.change_message(params) |> Map.put(:action, :validate)
    {:noreply, assign_form(socket, changeset)}
  end

  # The widget has a token: keep the latest. `nil` is the widget saying it has none (it expired, or failed).
  def handle_event("turnstile", %{"token" => token}, socket) do
    token = if is_binary(token) and token != "", do: token
    {:noreply, assign(socket, :turnstile_token, token)}
  end

  def handle_event("send", %{"contact" => params}, %{assigns: %{status: :writing}} = socket) do
    # What is on the page is what is sent, wherever the answer leads: the form keeps it.
    socket = assign_form(socket, Contact.change_message(%Message{}, params))

    with {:ok, message} <- Contact.review(params),
         :ok <- check_human(socket),
         {:ok, saved} <- Contact.submit(message, context(socket)) do
      {:noreply, socket |> assign(status: :sent, sent: saved, error: nil) |> new_check()}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}

      {:error, reason} ->
        {:noreply, socket |> assign(:error, reason) |> new_check()}
    end
  end

  # A second click that arrives while the first is being answered, or after the message went.
  def handle_event("send", _params, socket), do: {:noreply, socket}

  def handle_event("again", _params, socket) do
    {:noreply,
     socket
     |> assign(status: :writing, sent: nil, error: nil)
     |> assign_form(Contact.change_message(blank(socket.assigns.user, nil)))}
  end

  ## What the page knows

  defp signed_in_user(%{user: %{} = user}), do: user
  defp signed_in_user(_visitor), do: nil

  defp turnstile_site_key, do: Application.get_env(:quickslips, :turnstile)[:site_key]

  # The form starts with what a logged-in user's account says, and with the kind of message the link asked for.
  defp blank(user, topic) do
    message = if user, do: %Message{email: user.email, name: user.name}, else: %Message{}
    if topic, do: %{message | topic: topic}, else: message
  end

  defp topic(value), do: Enum.find(Message.topics(), &(Atom.to_string(&1) == value))

  defp about(value) when is_binary(value) do
    if Regex.match?(@about, value) and not String.contains?(value, ".."), do: value
  end

  defp about(_not_text), do: nil

  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset, as: :contact))

  defp check_human(%{assigns: %{turnstile_token: token}}) do
    case Turnstile.verify(token) do
      :ok -> :ok
      {:error, _reason} -> {:error, :check_failed}
    end
  end

  # A token is good for one check, whatever the answer was: the widget is asked for a new one.
  defp new_check(%{assigns: %{turnstile_site_key: nil}} = socket), do: socket

  defp new_check(socket) do
    socket |> assign(:turnstile_token, nil) |> push_event("turnstile:reset", %{})
  end

  # What the e-mails need to know of the visit: who, in which language, about which page, and the site's address.
  defp context(%{assigns: %{user: user, locale: locale, about: about}}) do
    %{user: user, locale: locale, page: about, site_url: Endpoint.url()}
  end

  ## The page

  # The kinds of message: the name used in the address and the e-mail, an icon, what it is called, what it is for.
  defp topics do
    for topic <- Message.topics(),
        do: {topic, topic_icon(topic), Topic.label(topic), Topic.help(topic)}
  end

  defp topic_icon(:change), do: "hero-sparkles"
  defp topic_icon(:feedback), do: "hero-chat-bubble-left-right"
  defp topic_icon(:problem), do: "hero-exclamation-triangle"
  defp topic_icon(:complaint), do: "hero-scale"
  defp topic_icon(:other), do: "hero-ellipsis-horizontal-circle"

  defp error_text(:check_failed) do
    gettext(
      "We could not confirm that you are not a robot. Wait a moment and try again, or reload the page."
    )
  end

  defp error_text(:limit),
    do: gettext("Too many messages have been sent today. Please try again tomorrow.")

  defp error_text(:storage) do
    gettext(
      "We could not send your message just now. Please try again in a little while, or write to us by e-mail."
    )
  end

  defp error_text(:unavailable), do: gettext("The contact form is not available at the moment.")

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale} active={:contact}>
      <div class="mx-auto max-w-2xl py-10">
        <h1
          id="contact-title"
          class="font-display text-3xl font-semibold tracking-tight text-ink sm:text-4xl"
        >
          {gettext("How can we help?")}
        </h1>
        <p id="contact-lead" class="mt-3 text-base/7 text-ink-muted">
          {gettext(
            "Want something changed or added? Have feedback? Something not working, or a dispute to sort out? Tell us here and we will read your message."
          )}
        </p>

        <.alert :if={@status == :unavailable} id="contact-unavailable" kind={:info} class="mt-8">
          {error_text(:unavailable)}
        </.alert>

        <.sent :if={@status == :sent} locale={@locale} message={@sent} />

        <.contact_form
          :if={@status == :writing}
          form={@form}
          about={@about}
          error={@error}
          contact_email={@contact_email}
          turnstile_site_key={@turnstile_site_key}
        />
      </div>
    </Layouts.app>
    """
  end

  attr :form, :map, required: true
  attr :about, :string, default: nil
  attr :error, :atom, default: nil
  attr :contact_email, :string, required: true
  attr :turnstile_site_key, :string, default: nil

  defp contact_form(assigns) do
    ~H"""
    <.form
      for={@form}
      id="contact-form"
      phx-change="validate"
      phx-submit="send"
      novalidate
      class="mt-8 space-y-6"
    >
      <p :if={@about} id="contact-about" class="text-sm/6 text-ink-muted">
        <.icon name="hero-link" class="mr-1 size-4 align-text-bottom" />
        {gettext("About this page: %{path}", path: @about)}
      </p>

      <fieldset id="contact-topics">
        <legend class="text-sm/5 font-medium text-ink">{gettext("What is it about?")}</legend>
        <div class="mt-3 grid gap-3 sm:grid-cols-2">
          <label
            :for={{value, icon, label, help} <- topics()}
            id={"contact-topic-#{value}"}
            class={[
              "flex cursor-pointer items-start gap-x-3 rounded-card border border-line-strong bg-surface p-4 transition-colors motion-reduce:transition-none",
              "hover:border-primary has-checked:border-primary has-checked:bg-primary-soft",
              "has-focus-visible:outline-2 has-focus-visible:outline-offset-2 has-focus-visible:outline-focus",
              value == :other && "sm:col-span-2"
            ]}
          >
            <input
              type="radio"
              name={@form[:topic].name}
              value={value}
              checked={to_string(@form[:topic].value) == to_string(value)}
              class="sr-only"
            />
            <.icon name={icon} class="mt-0.5 size-5 shrink-0 text-primary" />
            <span class="min-w-0">
              <span class="block text-sm/5 font-semibold text-ink">{label}</span>
              <span class="mt-0.5 block text-sm/5 text-ink-muted">{help}</span>
            </span>
          </label>
        </div>
      </fieldset>

      <div class="grid gap-x-4 sm:grid-cols-2">
        <.input
          field={@form[:name]}
          type="text"
          label={gettext("Your name (optional)")}
          autocomplete="name"
          maxlength="100"
        />
        <.input
          field={@form[:email]}
          type="email"
          label={gettext("Your e-mail")}
          help={gettext("We use it only to answer you.")}
          autocomplete="email"
          maxlength="160"
          required
        />
      </div>

      <.input
        field={@form[:message]}
        type="textarea"
        label={gettext("Your message")}
        help={
          gettext(
            "The more you tell us, the better we can help. Please do not write passwords or card numbers."
          )
        }
        rows="7"
        maxlength="4000"
        required
      />

      <%!-- The trap for robots: people do not see it and do not get to it with the keyboard. --%>
      <div class="absolute -left-[9999px] size-px overflow-hidden" aria-hidden="true">
        <.input
          field={@form[:website]}
          type="text"
          label="Leave this field empty"
          tabindex="-1"
          autocomplete="off"
        />
      </div>

      <div
        :if={@turnstile_site_key}
        id="contact-turnstile"
        phx-hook="ContactTurnstile"
        phx-update="ignore"
        data-site-key={@turnstile_site_key}
      >
      </div>

      <.alert :if={@error} id="contact-error" kind={:error}>{error_text(@error)}</.alert>

      <div class="flex flex-wrap items-center gap-x-5 gap-y-3">
        <.button id="contact-send" type="submit" phx-disable-with={gettext("Sending…")}>
          <.icon name="hero-paper-airplane" class="size-5" /> {gettext("Send message")}
        </.button>
        <p id="contact-email-fallback" class="text-sm/6 text-ink-muted">
          {gettext("Prefer e-mail?")}
          <a
            href={"mailto:" <> @contact_email}
            class="rounded-field font-medium text-primary hover:text-primary-hover focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-focus"
          >
            {@contact_email}
          </a>
        </p>
      </div>
    </.form>
    """
  end

  attr :locale, :map, required: true
  attr :message, :map, required: true, doc: "the message as it was kept, with its reference"

  defp sent(assigns) do
    ~H"""
    <%!-- Takes the focus: the button that was pressed is gone, and a keyboard or a screen reader must not be left with nothing. --%>
    <div
      id="contact-sent"
      role="status"
      tabindex="-1"
      phx-mounted={JS.focus()}
      class="mt-8 rounded-card border border-line bg-surface p-6 focus:outline-none sm:p-8"
    >
      <div class="flex items-start gap-x-4">
        <span class="flex size-10 shrink-0 items-center justify-center rounded-full bg-success-soft text-success">
          <.icon name="hero-check" class="size-6" />
        </span>
        <div class="min-w-0">
          <h2 class="font-display text-xl font-semibold tracking-tight text-ink">
            {gettext("Thank you, your message is on its way")}
          </h2>
          <p id="contact-sent-reference" class="mt-2 text-base/7 text-ink">
            {gettext("Your reference:")}
            <strong class="font-mono font-semibold tracking-wide">{@message.reference}</strong>
          </p>
          <p id="contact-sent-confirmation" class="mt-2 text-base/7 text-ink-muted">
            {gettext(
              "A confirmation is on its way to %{email}. If it does not arrive, look in your spam folder.",
              email: @message.email
            )}
          </p>
          <p class="mt-2 text-base/7 text-ink-muted">
            {gettext("We read every message. If we reply, it will be to the e-mail address you gave.")}
          </p>
          <div class="mt-6 flex flex-wrap gap-3">
            <.button id="contact-home" navigate={home_path(@locale)}>
              {gettext("Back to templates")}
            </.button>
            <.button id="contact-again" type="button" variant="secondary" phx-click="again">
              {gettext("Write another message")}
            </.button>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
