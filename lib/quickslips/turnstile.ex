defmodule QuickSlips.Turnstile do
  @moduledoc "Verifies a Cloudflare Turnstile token."

  @verify_url "https://challenges.cloudflare.com/turnstile/v0/siteverify"

  def verify(token, ip) when is_binary(token) and token != "" do
    secret = Application.get_env(:quickslips, :turnstile)[:secret_key]

    options =
      [
        url: @verify_url,
        form: [secret: secret, response: token, remoteip: ip],
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
