defmodule QuickSlipsWeb.UserLive.Login do
  use QuickSlipsWeb, :live_view

  alias QuickSlips.Accounts

    @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <.auth_card
        title={if @current_scope, do: "Confirm it is you", else: "Log in to QuickSlips"}
        subtitle={
          if @current_scope,
            do: "You need to reauthenticate to perform sensitive actions on your account.",
            else: "Welcome back."
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
          <:tab id="password" label="Password">
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
                label="Email address"
                autocomplete="username"
                spellcheck="false"
                required
                phx-mounted={JS.focus()}
              />
              <.input
                field={@form[:password]}
                type="password"
                label="Password"
                autocomplete="current-password"
                spellcheck="false"
                help="Forgot it? Use the Email link tab, then set a new password in Settings."
              />
              <div class="mt-4 space-y-3">
                <.button name={@form[:remember_me].name} value="true" block>
                  Log in and stay logged in
                </.button>
                <.button variant="secondary" block>Log in only this time</.button>
              </div>
            </.form>
          </:tab>
          <:tab id="link" label="Email link">
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
                label="Email address"
                autocomplete="username"
                spellcheck="false"
                required
                help="We email you a link that logs you in. No password needed."
              />
              <.button block class="mt-4">
                <.icon name="hero-envelope" class="size-5" /> Email me a link
              </.button>
            </.form>
          </:tab>
        </.tabs>

        <div class="mt-6">
          <.divider>or</.divider>
          <div class="mt-6"><.google_button /></div>
        </div>

        <:footer :if={!@current_scope}>
          New here?
          <.link
            navigate={~p"/users/register"}
            class="font-semibold text-primary hover:text-primary-hover hover:underline"
          >
            Sign up
          </.link>
        </:footer>
      </.auth_card>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form, trigger_submit: false, page_title: "Log in")}
  end

  @impl true
  def handle_event("submit_password", _params, socket) do
    {:noreply, assign(socket, :trigger_submit, true)}
  end

  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/users/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/users/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:quickslips, QuickSlips.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
