defmodule QuickSlipsWeb.TurnstileCheck do
  @moduledoc """
  The Turnstile check of a LiveView form (the log-in and sign-up pages): keeps the token the widget gives, uses it once, and asks the widget for a new one.

  The widget is drawn by `QuickSlipsWeb.UI.turnstile_check/1`, and its script (the `AuthTurnstile` hook of `assets/js/app.js`)
  sends each token to the LiveView as a `"turnstile"` event. A LiveView that uses this:

      def mount(_params, _session, socket), do: {:ok, TurnstileCheck.mount(socket)}

      def handle_event("turnstile", %{"token" => token}, socket),
        do: {:noreply, TurnstileCheck.put_token(socket, token)}

      # and where the form is sent: `TurnstileCheck.verify(socket)`, then `TurnstileCheck.renew(socket)` whatever the answer
      # was, because a token is good for one check.

  The address of the visitor is not given to Cloudflare, which does not need it: a LiveView cannot see it behind the proxy.
  """
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [push_event: 3]

  alias QuickSlips.Turnstile

  @doc "Adds the assigns of the check: the key of the widget (`nil` where there is none) and no token yet."
  def mount(socket),
    do:
      socket |> assign(:turnstile_site_key, Turnstile.site_key()) |> assign(:turnstile_token, nil)

  @doc "Keeps the token the widget gave. `nil`, or an empty one, is the widget saying it has none (it expired, or failed)."
  def put_token(socket, token) do
    assign(socket, :turnstile_token, if(is_binary(token) and token != "", do: token))
  end

  @doc "Asks Cloudflare whether the token is good: `:ok`, or `{:error, :check_failed}` (none, a bad one, or no answer)."
  def verify(%{assigns: %{turnstile_token: token}}) do
    case Turnstile.verify(token) do
      :ok -> :ok
      {:error, _reason} -> {:error, :check_failed}
    end
  end

  @doc "A token is good for one check, whatever the answer was: forgets it and asks the widget for a new one."
  def renew(%{assigns: %{turnstile_site_key: nil}} = socket),
    do: assign(socket, :turnstile_token, nil)

  def renew(socket) do
    socket |> assign(:turnstile_token, nil) |> push_event("turnstile:reset", %{})
  end
end
