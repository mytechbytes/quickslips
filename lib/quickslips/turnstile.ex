defmodule QuickSlips.Turnstile do
  @moduledoc "Verifies a Cloudflare Turnstile token."

  @verify_url "https://challenges.cloudflare.com/turnstile/v0/siteverify"

  # The address of the visitor is optional for Cloudflare. A page that is a LiveView does not have it behind the
  # proxy (only the controllers do), so it asks without.
  def verify(token, ip \\ nil)

  def verify(token, ip) when is_binary(token) and token != "" do
    secret = Application.get_env(:quickslips, :turnstile)[:secret_key]

    options =
      [
        url: @verify_url,
        form: [secret: secret, response: token] ++ if(ip, do: [remoteip: ip], else: []),
        retry: false,
        receive_timeout: 5_000
      ] ++
        Application.get_env(:quickslips, :turnstile_req_options, [])

    case Req.post(options) do
      {:ok, %{status: 200, body: %{"success" => true}}} -> :ok
      _ -> {:error, :turnstile_failed}
    end
  end

  def verify(_token, _ip), do: {:error, :turnstile_failed}
end
