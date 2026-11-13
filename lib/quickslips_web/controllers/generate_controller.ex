defmodule QuickSlipsWeb.GenerateController do
  use QuickSlipsWeb, :controller

  require Logger

  alias QuickSlips.Businesses
  alias QuickSlips.Documents
  alias QuickSlips.Downloads
  alias QuickSlips.Locales
  alias QuickSlips.Regions
  alias QuickSlips.Signatures
  alias QuickSlips.Stamps
  alias QuickSlips.Watermark
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
    with {:ok, page_locale} <- fetch_locale(params),
         {:ok, locale, currency} <- document_region(page_locale, params),
         {:ok, schema} <- Templates.get(slug, locale),
         {:ok, clean} <- validate(schema, data, locale),
         {:ok, business} <- load_business(conn, params),
         {:ok, signature} <- load_signature(conn, params),
         {:ok, driver_signature} <- load_driver_signature(conn, params),
         {:ok, extras} <- load_extra_signatures(conn, params),
         {:ok, stamp} <- load_stamp(conn, params),
         {:ok, watermark} <- Watermark.prepare(params["watermark"] || %{}),
         :ok <- verify_human(conn, params),
         {:ok, grant} <- Downloads.reserve(caller(conn)),
         paper =
           Map.merge(
             Templates.paper_data(schema, template, params["paper"]),
             Templates.margin_data(schema, template, params["margin"])
           ),
         pictures = Businesses.render_assets(business, signature, stamp, driver_signature, extras),
         pictures = %{
           data: pictures.data |> Map.merge(paper) |> Map.merge(watermark.data),
           files: Map.merge(pictures.files, watermark.files)
         },
         {:ok, pdf} <- render_or_refund(slug, template, clean, pictures, locale, currency, grant) do
      remember(
        conn,
        schema,
        template,
        clean,
        {business, signature, stamp, driver_signature, extras},
        locale,
        currency,
        Map.merge(paper, watermark.data)
      )

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

  # The signature is chosen apart from the business: one of the user's saved ones, or none (the place to sign by
  # hand). Looked up through the scope in the same way, so somebody else's signature is a 404.
  defp load_signature(conn, %{"signature_id" => id}) when id not in [nil, ""] do
    case conn.assigns[:current_scope] do
      %{user: %{}} = scope -> {:ok, Signatures.get_signature!(scope, id)}
      _anonymous -> {:ok, nil}
    end
  end

  defp load_signature(_conn, _params), do: {:ok, nil}

  # The driver's signature, the second one of a receipt: one of the user's saved signatures too.
  defp load_driver_signature(conn, %{"driver_signature_id" => id}) when id not in [nil, ""] do
    case conn.assigns[:current_scope] do
      %{user: %{}} = scope -> {:ok, Signatures.get_signature!(scope, id)}
      _anonymous -> {:ok, nil}
    end
  end

  defp load_driver_signature(_conn, _params), do: {:ok, nil}

  # The further signatures of a design (`signature_3`, ...): `extra_signature_ids` maps each slot to the id of one of the
  # user's saved signatures. Looked up through the scope, so somebody else's is a 404; a visitor has none.
  @extra_slots ~w(signature_3 signature_4 signature_5)

  defp load_extra_signatures(conn, %{"extra_signature_ids" => ids}) when is_map(ids) do
    case conn.assigns[:current_scope] do
      %{user: %{}} = scope ->
        {:ok,
         for {slot, id} <- ids, slot in @extra_slots, id not in [nil, ""], into: %{} do
           {slot, Signatures.get_signature!(scope, id)}
         end}

      _anonymous ->
        {:ok, %{}}
    end
  end

  defp load_extra_signatures(_conn, _params), do: {:ok, %{}}

  # What the history keeps of them, to draw them again: `%{"signatures" => %{"signature_3" => 12}}`.
  defp extra_signature_options(extras) when map_size(extras) == 0, do: %{}

  defp extra_signature_options(extras),
    do: %{"signatures" => Map.new(extras, fn {slot, signature} -> {slot, signature.id} end)}

  # The revenue stamp: "system:<name>" (one the site provides, for anybody), the id of one of the user's saved ones, or nothing (the
  # empty box). A saved one is looked up through the scope, so somebody else's is a 404; a visitor has none.
  defp load_stamp(_conn, %{"stamp" => "system:" <> id}) do
    if Stamps.system_stamp(id), do: {:ok, {:system, id}}, else: {:ok, nil}
  end

  defp load_stamp(conn, %{"stamp" => id}) when id not in [nil, ""] do
    case conn.assigns[:current_scope] do
      %{user: %{}} = scope -> {:ok, Stamps.get_stamp!(scope, id)}
      _anonymous -> {:ok, nil}
    end
  end

  defp load_stamp(_conn, _params), do: {:ok, nil}

  # The page's locale decides the language; the document may be for another country (and currency), chosen in the
  # "Region & tax" panel of the page.
  defp document_region(locale, params) do
    country = params["country"]
    locale = Locales.with_country(locale, country)

    case Regions.build(locale.country, params["currency"], locale.language) do
      {:ok, %{"currency" => %{"code" => code}}} -> {:ok, locale, code}
      {:error, _reason} -> {:error, :unknown_locale}
    end
  end

  defp render_or_refund(slug, template, clean, pictures, locale, currency, grant) do
    # The names of the pictures are added here, after validation, so a user can never choose them.
    %{data: image_names, files: files} = pictures

    case Renderer.render(slug, template, Map.merge(clean, image_names),
           assets: files,
           locale: base_code(locale),
           country: locale.country,
           currency: currency
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
  # The code of a locale that has a page: `hi-in` for Hindi made for Japan, whose own code is `hi-jp`.
  defp base_code(locale) do
    case Enum.find(
           Locales.live(),
           &(&1.language == locale.language and &1.country == locale.country)
         ) do
      %{code: code} ->
        code

      nil ->
        (Enum.find(Locales.live(), &(&1.language == locale.language)) || Locales.default()).code
    end
  end

  defp remember(
         conn,
         schema,
         template,
         clean,
         {business, signature, stamp, driver_signature, extras},
         locale,
         currency,
         paper
       ) do
    with %{user: %{}} = scope <- conn.assigns[:current_scope],
         attrs = %{
           "slug" => schema["slug"],
           "template" => template,
           "title" => Documents.build_title(schema, clean, short_months(schema, locale)),
           "data" => clean,
           "language" => locale.language,
           "options" =>
             %{"country" => locale.country, "currency" => currency}
             |> Map.merge(
               for(
                 {key, name} <- [{"paper_size", "paper"}, {"margin_size", "margin"}],
                 paper[key],
                 into: %{},
                 do: {name, paper[key]}
               )
             )
             |> Map.merge(extra_signature_options(extras))
             |> Map.merge(watermark_options(paper))
         },
         {:error, changeset} <-
           Documents.create_document(scope, attrs, business, signature, stamp, driver_signature) do
      Logger.warning("could not save a document in the history: #{inspect(changeset.errors)}")
    end

    :ok
  end

  # What the history keeps of the watermark: its settings, not the picture (that has to be chosen again).
  defp watermark_options(%{"watermark" => settings}),
    do: %{"watermark" => Map.delete(settings, "image")}

  defp watermark_options(_paper), do: %{}

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
