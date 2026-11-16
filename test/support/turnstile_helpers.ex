defmodule QuickSlips.TurnstileHelpers do
  @moduledoc """
  For tests of a LiveView form that asks for the Turnstile check (the log-in and sign-up pages): the widget cannot run
  in a test, so the test plays its part, sending the token to the page, and says what Cloudflare answers.
  """
  import Phoenix.LiveViewTest, only: [render_hook: 3]

  @doc "What Cloudflare answers to the next tokens: `true` (a person) or `false` (not). The page's process may ask."
  def turnstile_says(view, success?) do
    Req.Test.stub(QuickSlips.Turnstile, fn conn ->
      Req.Test.json(conn, %{"success" => success?})
    end)

    Req.Test.allow(QuickSlips.Turnstile, self(), view.pid)
    :ok
  end

  @doc "The widget gives the page a token (`nil` for none: it expired or failed)."
  def give_token(view, token \\ "a-token"),
    do: render_hook(view, "turnstile", %{"token" => token})

  @doc "The visitor passes the check: Cloudflare says yes, and the widget has given a token."
  def pass_turnstile(view) do
    turnstile_says(view, true)
    give_token(view)
    :ok
  end
end
