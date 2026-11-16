defmodule QuickSlipsWeb.UserLive.Registration do
  use QuickSlipsWeb, :live_view

  alias QuickSlips.Accounts
  alias QuickSlips.Accounts.User
  alias QuickSlips.AuthLimits
  alias QuickSlipsWeb.AuthMessages
  alias QuickSlipsWeb.ClientSession
  alias QuickSlipsWeb.TurnstileCheck

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale}>
      <.auth_card
        title={gettext("Create your account")}
        subtitle={gettext("Free to start. You will confirm your email next.")}
      >
        <.form for={@form} id="registration_form" phx-submit="save" phx-change="validate">
          <.input
            field={@form[:email]}
            type="email"
            label={gettext("Email address")}
            autocomplete="username"
            spellcheck="false"
            required
            phx-mounted={JS.focus()}
          />

          <.input
            field={@form[:password]}
            type="password"
            label={gettext("Password")}
            autocomplete="new-password"
            spellcheck="false"
            required
            help={
              gettext(
                "6 to 72 characters, with a lower-case letter, an upper-case letter and a number or symbol."
              )
            }
          />

          <.input
            field={@form[:password_confirmation]}
            type="password"
            label={gettext("Confirm password")}
            autocomplete="new-password"
            spellcheck="false"
            required
          />

          <.turnstile_check id="registration-turnstile" site_key={@turnstile_site_key} />

          <div class="pt-2">
            <.button phx-disable-with={gettext("Creating account...")} block>
              {gettext("Sign up")}
            </.button>
          </div>
        </.form>

        <div class="mt-6">
          <.divider>{gettext("or")}</.divider>
          <div class="mt-6"><.google_button /></div>
        </div>

        <:footer>
          {gettext("Already have an account?")}
          <.link
            navigate={~p"/users/log-in"}
            class="font-semibold text-primary hover:text-primary-hover hover:underline"
          >
            {gettext("Log in")}
          </.link>
        </:footer>
      </.auth_card>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, %{assigns: %{current_scope: %{user: user}}} = socket)
      when not is_nil(user) do
    {:ok, redirect(socket, to: QuickSlipsWeb.UserAuth.signed_in_path(socket))}
  end

  def mount(_params, session, socket) do
    # changeset = Accounts.change_user_email(%User{}, %{}, validate_unique: false)
    changeset =
      Accounts.change_user_registration(%User{}, %{},
        validate_unique: false,
        hash_password: false
      )

    socket =
      socket
      |> assign(:page_title, gettext("Sign up"))
      |> assign(:client_ip, ClientSession.client_ip(session))
      |> TurnstileCheck.mount()
      |> assign_form(changeset)

    {:ok, socket, temporary_assigns: [form: nil]}
  end

  @impl true
  def handle_event("turnstile", %{"token" => token}, socket) do
    {:noreply, TurnstileCheck.put_token(socket, token)}
  end

  # What is wrong with the form is told first, and costs nothing: no token is used and nothing is counted until
  # the form is good. Then the check, then the count of e-mails, then the account.
  #
  # The page never says whether the address already has an account: `Accounts.register_user_quietly/2` makes the
  # account for a new address, and for an address that has one it only sends the owner the e-mail, and in both cases
  # the answer is the same.
  def handle_event("save", %{"user" => user_params}, socket) do
    form =
      Accounts.change_user_registration(%User{}, user_params,
        validate_unique: false,
        hash_password: false
      )

    with true <- form.valid?,
         :ok <- TurnstileCheck.verify(socket),
         :ok <- AuthLimits.check_mail(socket.assigns.client_ip, user_params["email"]),
         {:ok, email} <-
           Accounts.register_user_quietly(user_params, &url(~p"/users/log-in/#{&1}")) do
      {:noreply,
       socket
       |> put_flash(
         :info,
         gettext(
           "An email was sent to %{email}, please access it and use the password you just chose to confirm your account.",
           email: email
         )
       )
       |> push_navigate(to: ~p"/users/log-in")}
    else
      false ->
        {:noreply, assign_form(socket, Map.put(form, :action, :insert))}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign_form(changeset) |> TurnstileCheck.renew()}

      {:error, :check_failed} ->
        {:noreply,
         socket |> put_flash(:error, AuthMessages.check_failed()) |> TurnstileCheck.renew()}

      {:error, {:slow_down, _seconds}} ->
        {:noreply,
         socket |> put_flash(:error, AuthMessages.too_many_mails()) |> TurnstileCheck.renew()}
    end
  end

  def handle_event("validate", %{"user" => user_params}, socket) do
    # changeset = Accounts.change_user_email(%User{}, user_params, validate_unique: false)
    changeset =
      Accounts.change_user_registration(%User{}, user_params,
        validate_unique: false,
        hash_password: false
      )

    {:noreply, assign_form(socket, Map.put(changeset, :action, :validate))}
  end

  defp assign_form(socket, %Ecto.Changeset{} = changeset) do
    form = to_form(changeset, as: "user")
    assign(socket, form: form)
  end
end
