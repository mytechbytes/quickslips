defmodule QuickSlipsWeb.UserLive.Login do
  use QuickSlipsWeb, :live_view

  alias QuickSlips.Accounts
  alias QuickSlips.AuthLimits
  alias QuickSlipsWeb.AuthMessages
  alias QuickSlipsWeb.ClientSession
  alias QuickSlipsWeb.TurnstileCheck

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope} locale={@locale}>
      <.auth_card
        title={
          if @current_scope, do: gettext("Confirm it is you"), else: gettext("Log in to QuickSlips")
        }
        subtitle={
          if @current_scope,
            do: gettext("You need to reauthenticate to perform sensitive actions on your account."),
            else: gettext("Welcome back.")
        }
      >
        <.alert
          :if={local_mail_adapter?()}
          kind={:info}
          title="You are running the local mail adapter."
          class="mb-5"
        >
          To see sent emails, visit <.link href="/dev/mailbox" class="font-semibold underline">the mailbox page</.link>.
        </.alert>

        <.tabs id="login-tabs" variant="pills">
          <:tab id="password" label={gettext("Password")}>
            <.form
              :let={f}
              for={@form}
              id="login_form_password"
              action={~p"/users/log-in"}
              phx-submit="submit_password"
              phx-trigger-action={@trigger_submit}
            >
              <.input
                readonly={!!@current_scope}
                field={f[:email]}
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
                autocomplete="current-password"
                spellcheck="false"
                help={
                  gettext("Forgot it? Use the Email link tab, then set a new password in Settings.")
                }
              />
              <%!-- The token of the Turnstile check goes with the form: the browser sends it, not the LiveView. It is only asked for after several wrong passwords. --%>
              <div id="login-turnstile-token" phx-update="ignore">
                <input type="hidden" name={@form[:turnstile_token].name} value="" />
              </div>
              <div class="mt-4 space-y-3">
                <.button name={@form[:remember_me].name} value="true" block>
                  {gettext("Log in and stay logged in")}
                </.button>
                <.button variant="secondary" block>{gettext("Log in only this time")}</.button>
              </div>
            </.form>
          </:tab>
          <:tab id="link" label={gettext("Email link")}>
            <.form
              :let={f}
              for={@form}
              id="login_form_magic"
              action={~p"/users/log-in"}
              phx-submit="submit_magic"
            >
              <.input
                readonly={!!@current_scope}
                field={f[:email]}
                type="email"
                label={gettext("Email address")}
                autocomplete="username"
                spellcheck="false"
                required
                help={gettext("We email you a link that logs you in. No password needed.")}
              />
              <.button block class="mt-4">
                <.icon name="hero-envelope" class="size-5" /> {gettext("Email me a link")}
              </.button>
            </.form>
          </:tab>
        </.tabs>

        <.turnstile_check
          id="login-turnstile"
          site_key={@turnstile_site_key}
          fill="#login-turnstile-token input"
        />

        <div class="mt-6">
          <.divider>{gettext("or")}</.divider>
          <div class="mt-6"><.google_button /></div>
        </div>

        <:footer :if={!@current_scope}>
          {gettext("New here?")}
          <.link
            navigate={~p"/users/register"}
            class="font-semibold text-primary hover:text-primary-hover hover:underline"
          >
            {gettext("Sign up")}
          </.link>
        </:footer>
      </.auth_card>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok,
     socket
     |> assign(form: form, trigger_submit: false, page_title: gettext("Log in"))
     |> assign(:client_ip, ClientSession.client_ip(session))
     |> TurnstileCheck.mount()}
  end

  @impl true
  def handle_event("turnstile", %{"token" => token}, socket) do
    {:noreply, TurnstileCheck.put_token(socket, token)}
  end

  # The password is checked by the controller that the form is sent to, which does its own counting (wrong passwords)
  # and asks for the Turnstile check only after several of them.
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  # An e-mail goes to whatever address is typed, so the check comes first and every address is counted. The answer is
  # the same whether the address has an account or not, and it comes as quickly: the sending is in a task.
  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket)
      when is_binary(email) do
    with :ok <- TurnstileCheck.verify(socket),
         :ok <- AuthLimits.check_mail(socket.assigns.client_ip, email) do
      Accounts.send_login_instructions_later(email, &url(~p"/users/log-in/#{&1}"))

      info =
        gettext(
          "If your email is in our system, you will receive instructions for logging in shortly."
        )

      {:noreply,
       socket
       |> put_flash(:info, info)
       |> push_navigate(to: ~p"/users/log-in")}
    else
      {:error, :check_failed} ->
        {:noreply,
         socket |> put_flash(:error, AuthMessages.check_failed()) |> TurnstileCheck.renew()}

      {:error, {:slow_down, _seconds}} ->
        {:noreply,
         socket |> put_flash(:error, AuthMessages.too_many_mails()) |> TurnstileCheck.renew()}
    end
  end

  defp local_mail_adapter? do
    Application.get_env(:quickslips, QuickSlips.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
