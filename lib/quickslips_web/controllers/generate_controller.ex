defmodule QuickSlipsWeb.GenerateController do
  use QuickSlipsWeb, :controller

  require Logger

  alias QuickSlips.Businesses
  alias QuickSlips.Documents
  alias QuickSlips.Downloads
  alias QuickSlips.Locales
  alias QuickSlips.Regions
  alias QuickSlips.Templates.Items
  alias QuickSlips.Templates.Validator
  alias QuickSlips.Templates
  alias QuickSlips.Render.Renderer
  alias QuickSlipsWeb.ErrorMessages

  action_fallback QuickSlipsWeb.FallbackController

  # `locale` ("hi-in") says in which language the document is written and for which country its numbers and
  # dates are. A client that does not send one (a page loaded before this existed) gets the default.
  def create(conn, %{"slug" => slug, "template" => template, "data" => data} = params)
      when is_map(data) do
    with {:ok, locale} <- fetch_locale(params),
         {:ok, schema} <- Templates.get(slug, locale),
         {:ok, clean} <- validate(schema, data, locale),
         {:ok, business} <- load_business(conn, params),
         :ok <- verify_human(conn, params),
         {:ok, grant} <- Downloads.reserve(caller(conn)),
         {:ok, pdf} <- render_or_refund(slug, template, clean, business, locale, grant) do
      remember(conn, schema, template, clean, business, locale)

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

  # What is wrong with the data is told in the language of the page the visitor is on.
  defp validate(schema, data, locale) do
    # A page that was open before a bill had a table of items still sends the numbered fields.
    case Validator.validate(schema, Items.upgrade(schema, data)) do
      {:ok, clean} ->
        {:ok, clean}

      {:error, {:validation, errors}} ->
        {:error, {:validation, ErrorMessages.translate_validation(errors, locale.language)}}
    end
  end

  defp fetch_locale(params) do
    case Locales.fetch(Map.get(params, "locale", Locales.default().code)) do
      {:ok, locale} -> {:ok, locale}
      :error -> {:error, :unknown_locale}
    end
  end

  # A logged-in user may attach one of their saved businesses: its logo and signature are drawn on the
  # document. The lookup goes through the scope, so someone else's business is a 404, never their picture.
  defp load_business(conn, %{"business_id" => id}) when id not in [nil, ""] do
    case conn.assigns[:current_scope] do
      %{user: %{}} = scope -> {:ok, Businesses.get_business!(scope, id)}
      _anonymous -> {:ok, nil}
    end
  end

  defp load_business(_conn, _params), do: {:ok, nil}

  defp render_or_refund(slug, template, clean, business, locale, grant) do
    # The names of the pictures are added here, after validation, so a user can never choose them.
    %{data: image_names, files: files} = Businesses.render_assets(business)

    case Renderer.render(slug, template, Map.merge(clean, image_names),
           assets: files,
           locale: locale.code
         ) do
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
  defp remember(conn, schema, template, clean, business, locale) do
    with %{user: %{}} = scope <- conn.assigns[:current_scope],
         attrs = %{
           "slug" => schema["slug"],
           "template" => template,
           "title" => Documents.build_title(schema, clean, short_months(schema, locale)),
           "data" => clean,
           "language" => locale.language,
           "options" => %{
             "country" => locale.country,
             "currency" => Regions.default_currency(locale.country)
           }
         },
         {:error, changeset} <- Documents.create_document(scope, attrs, business) do
      Logger.warning("could not save a document in the history: #{inspect(changeset.errors)}")
    end

    :ok
  end

  # The short names of the months in the language of the document, for its title in the history.
  defp short_months(schema, locale) do
    case Templates.print_text(schema["slug"], locale) do
      %{"months_short" => months} -> months
      _ -> nil
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
