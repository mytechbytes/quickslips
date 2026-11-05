defmodule QuickSlipsWeb.GenerateController do
  use QuickSlipsWeb, :controller

  alias QuickSlips.Downloads
  alias QuickSlips.Templates.Validator
  alias QuickSlips.Templates
  alias QuickSlips.Render.Renderer

  action_fallback QuickSlipsWeb.FallbackController

  def create(conn, %{"slug" => slug, "template" => template, "data" => data} = params)
      when is_map(data) do
    with {:ok, schema} <- Templates.get(slug),
         {:ok, clean} <- Validator.validate(schema, data),
         :ok <- verify_human(conn, params),
         {:ok, grant} <- Downloads.reserve(caller(conn)),
         {:ok, pdf} <- render_or_refund(slug, template, clean, grant) do
      conn
      |> put_resp_header("x-downloads-remaining", Integer.to_string(grant.remaining))
      |> send_download(
        {:binary, pdf},
        filename: "#{slug}.pdf",
        content_type: "application/pdf"
      )
    end
  end

  def create(_conn, _params), do: {:error, :bad_request}

  defp render_or_refund(slug, template, clean, grant) do
    case Renderer.render(slug, template, clean) do
      {:ok, pdf} ->
        {:ok, pdf}

      {:error, _reason} = error ->
        Downloads.refund(grant)
        error
    end
  end

  defp caller(conn) do
    scope = conn.assigns[:current_scope]

    %{
      user: scope && scope.user,
      visitor_id: conn.assigns.visitor_id,
      ip: conn.remote_ip |> :inet.ntoa() |> to_string()
    }
  end

  defp verify_human(conn, params) do
    case conn.assigns[:current_scope] do
      %{user: %{}} -> :ok
      _anonymous -> QuickSlips.Turnstile.verify(params["turnstile_token"], caller(conn).ip)
    end
  end
end
