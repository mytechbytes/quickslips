defmodule QuickSlipsWeb.GenerateController do
  use QuickSlipsWeb, :controller

  require Logger

  alias QuickSlips.Businesses
  alias QuickSlips.Documents
  alias QuickSlips.Downloads
  alias QuickSlips.Templates.Validator
  alias QuickSlips.Templates
  alias QuickSlips.Render.Renderer

  action_fallback QuickSlipsWeb.FallbackController

  def create(conn, %{"slug" => slug, "template" => template, "data" => data} = params)
      when is_map(data) do
    with {:ok, schema} <- Templates.get(slug),
         {:ok, clean} <- Validator.validate(schema, data),
         {:ok, business} <- load_business(conn, params),
         :ok <- verify_human(conn, params),
         {:ok, grant} <- Downloads.reserve(caller(conn)),
         {:ok, pdf} <- render_or_refund(slug, template, clean, business, grant) do
      remember(conn, schema, template, clean, business)

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

  # A logged-in user may attach one of their saved businesses: its logo and signature are drawn on the
  # document. The lookup goes through the scope, so someone else's business is a 404, never their picture.
  defp load_business(conn, %{"business_id" => id}) when id not in [nil, ""] do
    case conn.assigns[:current_scope] do
      %{user: %{}} = scope -> {:ok, Businesses.get_business!(scope, id)}
      _anonymous -> {:ok, nil}
    end
  end

  defp load_business(_conn, _params), do: {:ok, nil}

  defp render_or_refund(slug, template, clean, business, grant) do
    # The names of the pictures are added here, after validation, so a user can never choose them.
    %{data: image_names, files: files} = Businesses.render_assets(business)

    case Renderer.render(slug, template, Map.merge(clean, image_names), assets: files) do
      {:ok, pdf} ->
        {:ok, pdf}

      {:error, _reason} = error ->
        Downloads.refund(grant)
        error
    end
  end

  # A logged-in user gets the document in their history. What is kept is the data, not the PDF: a few
  # hundred bytes that can be rendered again. The history must never cost the user the PDF they just
  # got, so a failure is logged and nothing more.
  defp remember(conn, schema, template, clean, business) do
    with %{user: %{}} = scope <- conn.assigns[:current_scope],
         attrs = %{
           "slug" => schema["slug"],
           "template" => template,
           "title" => Documents.build_title(schema, clean),
           "data" => clean
         },
         {:error, changeset} <- Documents.create_document(scope, attrs, business) do
      Logger.warning("could not save a document in the history: #{inspect(changeset.errors)}")
    end

    :ok
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
