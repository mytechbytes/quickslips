defmodule QuickSlipsWeb.TranslationTest do
  use QuickSlipsWeb.ConnCase

  import Phoenix.LiveViewTest

  # The text of the site's own pages, in each language. The wording of the translations is in priv/gettext.

  describe "the catalogue" do
    test "speaks English as it always did", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/en-in")

      assert has_element?(view, "#home-title", "Bills and receipts, ready in seconds")
      assert has_element?(view, "#header-login", "Log in")
      assert has_element?(view, "#header-signup", "Sign up")
      assert has_element?(view, "#chip-all", "All")

      assert has_element?(
               view,
               ~s(#template-search[placeholder="Search templates, like fuel or rent"])
             )

      assert has_element?(view, "#cta-signup", "Sign up")
      assert html =~ "You are responsible for their accuracy"
    end

    test "speaks Hindi: the hero, the header, the search, the chips, the call to action and the footer",
         %{
           conn: conn
         } do
      {:ok, view, html} = live(conn, ~p"/hi-in")

      assert has_element?(view, "#home-title", "बिल और रसीदें, कुछ ही सेकंड में तैयार")
      assert has_element?(view, "#nav-templates", "टेम्पलेट")
      assert has_element?(view, "#header-login", "लॉग इन")
      assert has_element?(view, "#header-signup", "साइन अप")
      assert has_element?(view, ~s(#template-search[placeholder="टेम्पलेट खोजें, जैसे पेट्रोल या किराया"]))
      assert has_element?(view, "#chip-all", "सभी")
      assert has_element?(view, "#cta-login", "लॉग इन")
      assert html =~ "हम आपके दिए गए विवरण से दस्तावेज़ बनाते हैं"
      assert html =~ "© #{Date.utc_today().year} QuickSlips."
    end

    test "speaks Spanish", %{conn: conn} do
      {:ok, view, html} = live(conn, ~p"/es-es")

      assert has_element?(view, "#home-title", "Facturas y recibos, listos en segundos")
      assert has_element?(view, "#header-login", "Iniciar sesión")
      assert has_element?(view, "#header-signup", "Registrarse")
      assert has_element?(view, "#chip-all", "Todas")
      assert has_element?(view, "#cta-signup", "Registrarse")
      assert html =~ "Creamos documentos a partir de los datos que introduces"
    end

    test "keeps speaking English in the English page after a Hindi one, on the same connection",
         %{conn: conn} do
      {:ok, _view, _html} = live(conn, ~p"/hi-in")
      {:ok, view, _html} = live(conn, ~p"/en-in")

      assert has_element?(view, "#home-title", "Bills and receipts, ready in seconds")
    end

    test "the page title and the description are in the language too", %{conn: conn} do
      html = conn |> get(~p"/hi-in") |> html_response(200) |> LazyHTML.from_document()

      assert html |> LazyHTML.query("title") |> LazyHTML.text() =~ "मुफ़्त बिल और रसीद जनरेटर"

      assert html |> LazyHTML.query("meta[name=description]") |> LazyHTML.attribute("content") ==
               ["बिल और रसीदें कुछ ही सेकंड में PDF के रूप में बनाएं।"]
    end
  end

  describe "a bill" do
    defp attr(html, selector, name),
      do: html |> LazyHTML.from_document() |> LazyHTML.query(selector) |> LazyHTML.attribute(name)

    test "has its buttons and messages in the language", %{conn: conn} do
      for {path, button, preview} <- [
            {"/en-in/fuel-bill-generator", "Download PDF", "Preview loads here…"},
            {"/hi-in/fuel-bill-generator", "PDF डाउनलोड करें", "प्रीव्यू यहाँ दिखेगा…"},
            {"/es-es/generador-de-factura-de-gasolina", "Descargar PDF",
             "La vista previa aparecerá aquí…"}
          ] do
        html = conn |> get(path) |> html_response(200)
        document = LazyHTML.from_document(html)

        assert document |> LazyHTML.query("#download-button") |> LazyHTML.text() =~ button
        assert document |> LazyHTML.query("#bill-preview") |> LazyHTML.text() =~ preview
      end
    end

    test "hands the form's script its messages in the language, with the places left to fill", %{
      conn: conn
    } do
      for {path, language} <- [
            {"/en-in/fuel-bill-generator", "en"},
            {"/hi-in/fuel-bill-generator", "hi"},
            {"/es-es/generador-de-factura-de-gasolina", "es"}
          ] do
        [json] = conn |> get(path) |> html_response(200) |> attr("#bill-app", "data-i18n")
        strings = Jason.decode!(json)

        assert Map.keys(strings) |> Enum.sort() ==
                 ~w(add_item amount creating downloaded error fill_business fix_fields group_business group_charges group_customer group_details group_document group_items group_payment group_registration limit_reached other_rate pick_business preview_alt preview_failed preview_updating quota_anonymous quota_user remove_item save_seller seller_created seller_error_name_blank seller_error_tax_id_invalid seller_updated signature_error_file_too_large signature_error_limit_reached signature_error_name_blank signature_error_name_taken signature_error_no_file signature_error_too_large signature_error_unsupported_type signature_saved stamp_error_limit_reached stamp_error_name_blank stamp_error_name_taken stamp_saved subtotal type_rate verify_failed)

        # The name of the registration number is filled in by the script; the most signatures is filled in here.
        assert strings["seller_error_tax_id_invalid"] =~ "{label}", language
        refute strings["seller_error_tax_id_invalid"] =~ "%{"
        assert strings["signature_error_limit_reached"] =~ "20"
        assert strings["stamp_error_limit_reached"] =~ "10"
        refute strings["stamp_error_limit_reached"] =~ "%{"
        refute strings["signature_error_limit_reached"] =~ "%{"

        # The script fills `{remaining}` and `{limit}` in, so they must survive the translation.
        for key <- ["quota_anonymous", "quota_user"] do
          assert strings[key] =~ "{remaining}" and strings[key] =~ "{limit}", "#{language} #{key}"
          refute strings[key] =~ "%{"
        end
      end

      [json] =
        conn
        |> get(~p"/en-in/fuel-bill-generator")
        |> html_response(200)
        |> attr("#bill-app", "data-i18n")

      assert Jason.decode!(json)["quota_anonymous"] ==
               "{remaining} of {limit} free downloads left today"

      assert Jason.decode!(json)["creating"] == "Creating your PDF…"

      [json] =
        conn
        |> get(~p"/hi-in/fuel-bill-generator")
        |> html_response(200)
        |> attr("#bill-app", "data-i18n")

      assert Jason.decode!(json)["creating"] == "आपका PDF बन रहा है…"
    end

    test "tells a visitor who has used the free downloads what to do, in the language", %{
      conn: conn
    } do
      html = conn |> get(~p"/es-es/generador-de-factura-de-gasolina") |> html_response(200)

      prompt =
        html |> LazyHTML.from_document() |> LazyHTML.query("#login-prompt") |> LazyHTML.text()

      assert prompt =~ "Has usado tus descargas gratuitas de hoy"
      assert prompt =~ "Iniciar sesión"
      assert prompt =~ "Registrarse"
    end
  end

  describe "the log-in and sign-up pages" do
    test "speak the language of the page the visitor came from", %{conn: conn} do
      conn = get(conn, ~p"/hi-in")

      {:ok, view, _html} = conn |> recycle() |> live(~p"/users/log-in")

      assert has_element?(view, "h1", "QuickSlips में लॉग इन करें")
      assert has_element?(view, "#login-tabs-tab-password", "पासवर्ड")
      assert has_element?(view, "#login-tabs-tab-link", "ईमेल लिंक")
      assert has_element?(view, "#google-login", "Google से जारी रखें")

      {:ok, view, _html} = conn |> recycle() |> live(~p"/users/register")

      assert has_element?(view, "h1", "अपना खाता बनाएं")
      assert has_element?(view, "#registration_form button", "साइन अप")
    end

    test "and in Spanish", %{conn: conn} do
      conn = get(conn, ~p"/es-es")

      {:ok, view, _html} = conn |> recycle() |> live(~p"/users/log-in")

      assert has_element?(view, "h1", "Inicia sesión en QuickSlips")
      assert has_element?(view, "#google-login", "Continuar con Google")
    end

    test "say what is wrong with a form in the language", %{conn: conn} do
      conn = get(conn, ~p"/es-es")
      {:ok, view, _html} = conn |> recycle() |> live(~p"/users/register")

      html =
        view
        |> form("#registration_form", user: %{email: "not an email", password: "abc"})
        |> render_change()

      assert html =~ "debe tener el signo @ y no contener espacios"
      assert html =~ "debe tener al menos 6 caracteres"
      assert html =~ "al menos una letra mayúscula"
    end

    test "a flash that a controller sets is in the language too", %{conn: conn} do
      conn = get(conn, ~p"/hi-in")

      conn =
        conn
        |> recycle()
        |> post(~p"/users/log-in", %{
          "user" => %{"email" => "nobody@example.com", "password" => "Wrong pass 1"}
        })

      assert Phoenix.Flash.get(conn.assigns.flash, :error) == "ईमेल या पासवर्ड गलत है"
    end
  end

  describe "the app a logged-in user sees" do
    setup :register_and_log_in_user

    test "has its menus in the language", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/es-es")

      assert has_element?(view, "#new-document", "Nuevo documento")
      assert has_element?(view, "#nav-dashboard", "Panel")
      assert has_element?(view, "#nav-history", "Documentos")
      assert has_element?(view, "#nav-businesses", "Empresas guardadas")
      assert has_element?(view, "#nav-signatures", "Firmas")
      assert has_element?(view, "#nav-settings", "Ajustes")
    end

    test "and the pages that are not translated yet keep their own words, inside the translated menus",
         %{conn: conn} do
      conn = get(conn, ~p"/hi-in")
      {:ok, view, _html} = conn |> recycle() |> live(~p"/history")

      assert has_element?(view, "#nav-history", "दस्तावेज़")
      assert has_element?(view, "h1", "Documents")
    end
  end
end
