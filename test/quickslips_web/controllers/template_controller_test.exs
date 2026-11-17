defmodule QuickSlipsWeb.TemplateControllerTest do
  use QuickSlipsWeb.ConnCase

  import QuickSlips.AccountsFixtures
  import QuickSlips.BusinessesFixtures
  import QuickSlips.DocumentsFixtures
  import QuickSlips.SignaturesFixtures
  import QuickSlips.StampsFixtures

  test "shows a template", %{conn: conn} do
    conn = get(conn, ~p"/en-in/fuel-bill-generator")
    assert html_response(conn, 200) =~ "Fuel Bill Generator"
  end

  test "unknown slug is a 404", %{conn: conn} do
    assert_error_sent 404, fn -> get(conn, ~p"/no-such-bill") end
    assert_error_sent 404, fn -> get(conn, ~p"/en-in/no-such-bill") end
  end

  # The head of a page, as {name, attribute} pairs: `attrs(html, "link[rel=alternate]", "hreflang")`.
  defp attrs(html, selector, attribute) do
    html |> LazyHTML.from_document() |> LazyHTML.query(selector) |> LazyHTML.attribute(attribute)
  end

  describe "locales" do
    @pages [
      {"en-in", "fuel-bill-generator", "en-IN", "Fuel Bill Generator"},
      {"hi-in", "fuel-bill-generator", "hi-IN", "पेट्रोल बिल जनरेटर"},
      {"es-es", "generador-de-factura-de-gasolina", "es-ES", "Generador de Factura de Gasolina"}
    ]

    test "the same bill is a page in each language, with its own lang and title", %{conn: conn} do
      for {locale, slug, lang, title} <- @pages do
        html = conn |> get("/#{locale}/#{slug}") |> html_response(200)

        assert attrs(html, "html", "lang") == [lang]

        assert [h1] =
                 html
                 |> LazyHTML.from_document()
                 |> LazyHTML.query("h1")
                 |> Enum.map(&LazyHTML.text/1)

        assert h1 == title
        assert html =~ ~s(data-locale="#{locale}")
      end
    end

    test "the page carries the words and the region of its locale for the preview", %{conn: conn} do
      html = conn |> get(~p"/es-es/generador-de-factura-de-gasolina") |> html_response(200)

      assert [region] = attrs(html, "#bill-app", "data-region") |> Enum.map(&Jason.decode!/1)
      assert region["currency"] == %{"code" => "EUR", "symbol" => "€", "decimals" => 2}
      assert region["number"]["decimal"] == ","

      assert [text] = attrs(html, "#bill-app", "data-text") |> Enum.map(&Jason.decode!/1)
      assert text["lang"] == "es"
      assert text["print"]["total"] == "Total"

      # The form starts with a sample that fits the country, in its language.
      assert [sample] = attrs(html, "#bill-app", "data-sample") |> Enum.map(&Jason.decode!/1)
      assert sample["station_name"] == "Gasolinera El Sol"
      assert sample["rate"] == 1.58

      assert [schema] = attrs(html, "#bill-app", "data-schema") |> Enum.map(&Jason.decode!/1)
      assert schema["slug"] == "fuel-bill"

      assert Enum.find(schema["fields"], &(&1["key"] == "rate"))["label"] ==
               "Precio por litro ({currency})"
    end

    test "a page names itself and its other languages to search engines", %{conn: conn} do
      html = conn |> get(~p"/hi-in/fuel-bill-generator") |> html_response(200)
      base = QuickSlipsWeb.Endpoint.url()

      assert attrs(html, "link[rel=canonical]", "href") == ["#{base}/hi-in/fuel-bill-generator"]

      alternates =
        html
        |> LazyHTML.from_document()
        |> LazyHTML.query("link[rel=alternate][hreflang]")
        |> Enum.map(&{LazyHTML.attribute(&1, "hreflang"), LazyHTML.attribute(&1, "href")})

      assert Enum.map(alternates, &elem(&1, 0)) ==
               Enum.map(
                 ~w(en-IN hi-IN es-ES en-US zh-CN de-DE ja-JP en-GB fr-FR it-IT pt-BR en-CA fr-CA x-default),
                 &[&1]
               )

      assert Enum.at(alternates, 0) == {["en-IN"], ["#{base}/en-in/fuel-bill-generator"]}

      assert Enum.at(alternates, 2) ==
               {["es-ES"], ["#{base}/es-es/generador-de-factura-de-gasolina"]}

      assert List.last(alternates) == {["x-default"], ["#{base}/en-in/fuel-bill-generator"]}
    end

    test "a bill with one language only names that one, and the query is not part of the canonical",
         %{conn: conn} do
      html = conn |> get(~p"/en-in/courier-receipt-generator?from=3") |> html_response(200)
      base = QuickSlipsWeb.Endpoint.url()

      assert attrs(html, "link[rel=canonical]", "href") == [
               "#{base}/en-in/courier-receipt-generator"
             ]

      assert attrs(html, "link[rel=alternate]", "hreflang") ==
               ["en-IN", "en-US", "en-GB", "en-CA", "x-default"]
    end

    test "a bill that is not in the language of the locale is a 404, not English under another address",
         %{conn: conn} do
      assert_error_sent 404, fn -> get(conn, ~p"/hi-in/courier-receipt-generator") end
      assert_error_sent 404, fn -> get(conn, ~p"/es-es/courier-receipt-generator") end
    end

    test "the slug of one locale is not an address in another", %{conn: conn} do
      assert_error_sent 404, fn -> get(conn, ~p"/en-in/generador-de-factura-de-gasolina") end
      assert_error_sent 404, fn -> get(conn, ~p"/es-es/fuel-bill-generator") end
      # the internal slug is not an address either
      assert_error_sent 404, fn -> get(conn, ~p"/en-in/fuel-bill") end
    end

    test "a locale that is not live, or not a locale, is a 404", %{conn: conn} do
      assert_error_sent 404, fn -> get(conn, ~p"/es-mx/generador-de-factura-de-gasolina") end
      assert_error_sent 404, fn -> get(conn, ~p"/xx-yy/fuel-bill-generator") end
      assert_error_sent 404, fn -> get(conn, ~p"/EN-IN/fuel-bill-generator") end
    end
  end

  describe "old addresses" do
    test "move permanently to the page under the default locale", %{conn: conn} do
      for {old, new} <- [
            {"fuel-bill", "/en-in/fuel-bill-generator"},
            {"rent-receipt", "/en-in/rent-receipt-generator"},
            {"taxi-receipt", "/en-in/cab-bill-generator"},
            {"hotel-invoice", "/en-in/hotel-bill-generator"},
            {"service-invoice", "/en-in/invoice-generator"}
          ] do
        conn = get(conn, "/#{old}")

        assert conn.status == 301
        assert redirected_to(conn, 301) == new
      end
    end

    test "keep the query, so a bookmarked edit link still opens the document", %{conn: conn} do
      conn = get(conn, "/fuel-bill?from=12")

      assert redirected_to(conn, 301) == "/en-in/fuel-bill-generator?from=12"
    end

    test "that were never addresses are a 404", %{conn: conn} do
      assert_error_sent 404, fn -> get(conn, "/nope") end
      assert_error_sent 404, fn -> get(conn, "/_shared") end
      assert_error_sent 404, fn -> get(conn, "/fuel-bill/anything") end
    end
  end

  describe "Turnstile site key" do
    setup do
      previous = Application.get_env(:quickslips, :turnstile)
      Application.put_env(:quickslips, :turnstile, site_key: "test-site-key", secret_key: "x")
      on_exit(fn -> Application.put_env(:quickslips, :turnstile, previous) end)
    end

    test "is on the page for visitors", %{conn: conn} do
      html = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)
      assert html =~ ~s(data-turnstile-site-key="test-site-key")
    end

    test "is left out for logged-in users", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      refute conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200) =~
               "data-turnstile-site-key"
    end
  end

  describe "saved businesses" do
    test "a logged-in user's own businesses are on the page, and nobody else's", %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      business_fixture(scope, %{name: "Sunrise Fuel Station", gstin: "29ABCDE1234F1Z5"})
      other = user_scope_fixture()
      business_fixture(other, %{name: "Somebody Else's Pump", gstin: "29ABCDE1234F1Z5"})

      html = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)

      assert html =~ "Sunrise Fuel Station"
      refute html =~ "Somebody Else"
    end

    test "only the fields the form needs reach the page", %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      business_fixture(scope, %{gstin: "29ABCDE1234F1Z5"})

      html = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)

      refute html =~ "user_id"
      refute html =~ "inserted_at"
      refute html =~ "logo_path"
    end

    test "the web addresses of the pictures are on the page, not the stored paths", %{conn: conn} do
      %{conn: conn, user: user, scope: scope} = register_and_log_in_user(%{conn: conn})
      logo = QuickSlips.UploadsFixtures.stored_image(user.id)
      business_fixture(scope, %{name: "Sunrise Fuel Station"}, %{logo_path: logo})

      html = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)

      assert html =~ "/uploads/#{logo}"
      assert html =~ "&quot;signature_id&quot;:null"
    end

    test "a business names its default signature by id, and the picture is not part of it", %{
      conn: conn
    } do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      signature = signature_fixture(scope)
      business_fixture(scope, %{name: "Sunrise Fuel Station", signature_id: signature.id})

      html = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)
      [businesses] = html |> attrs("#bill-app", "data-businesses") |> Enum.map(&Jason.decode!/1)

      assert [%{"signature_id" => id} = business] = businesses
      assert id == signature.id
      refute Map.has_key?(business, "signature_url")
    end

    test "a visitor gets an empty list", %{conn: conn} do
      html = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)
      assert html =~ ~s(data-businesses="[]")
    end
  end

  describe "saved signatures" do
    test "a logged-in user's own signatures are on the page, with their web address, and nobody else's",
         %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      mine = signature_fixture(scope, %{name: "Owner"})
      signature_fixture(user_scope_fixture(), %{name: "Somebody Else's"})

      html = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)
      [signatures] = html |> attrs("#bill-app", "data-signatures") |> Enum.map(&Jason.decode!/1)

      assert [%{"id" => id, "name" => "Owner", "url" => url} = signature] = signatures
      assert id == mine.id
      assert url == "/uploads/#{mine.path}"
      assert Map.keys(signature) |> Enum.sort() == ["id", "name", "url"]
      refute html =~ "Somebody Else"
    end

    test "the select offers no signature first, then the saved ones", %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      signature_fixture(scope, %{name: "Manager"})
      signature_fixture(scope, %{name: "Owner"})

      html = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)
      options = html |> LazyHTML.from_document() |> LazyHTML.query("#signature-select option")

      assert LazyHTML.attribute(options, "value") |> hd() == ""
      assert LazyHTML.text(options) =~ "No signature (placeholder only)"
      assert options |> LazyHTML.text() |> String.split() |> Enum.take(-2) == ["Manager", "Owner"]
      assert [_] = attrs(html, "#signature-name", "maxlength")
      assert [_] = attrs(html, "#signature-file", "accept")
      assert [_] = attrs(html, "#signature-save", "id")
      # a logged-in user has it open: nothing is locked, and there is nothing to sign up for
      assert attrs(html, "#signature-select", "disabled") == []
      assert attrs(html, "#signature-open", "disabled") == []
      assert attrs(html, "#signature-signup", "id") == []
    end

    test "is in the language of the page", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      html = conn |> get(~p"/es-es/generador-de-factura-de-gasolina") |> html_response(200)

      assert html =~ "Sin firma (solo el espacio para firmar)"
      assert html =~ "Guardar una firma nueva"
    end

    test "the choice is shown for a design that has a place to sign, and hidden for one that has not",
         %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      fuel = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)
      grocery = conn |> get(~p"/en-in/grocery-bill-generator") |> html_response(200)

      refute hd(attrs(fuel, "#signature-section", "class")) =~ "hidden"
      assert hd(attrs(grocery, "#signature-section", "class")) =~ "hidden"
    end

    test "the script learns which designs have a place to sign", %{conn: conn} do
      html = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)
      [schema] = html |> attrs("#bill-app", "data-schema") |> Enum.map(&Jason.decode!/1)

      signs = Map.new(schema["templates"], &{&1["id"], &1["signature"]})

      assert signs == %{
               "t1" => true,
               "t2" => false,
               "t3" => false,
               "t4" => false,
               "t5" => true,
               "t6" => false
             }
    end

    test "the revenue stamp: empty box, the default one, then the saved ones; for a receipt that has a place for it",
         %{
           conn: conn
         } do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      stamp_fixture(scope, %{name: "Landlord"})
      theirs = stamp_fixture(user_scope_fixture(), %{name: "Somebody Else's"})

      html = conn |> get(~p"/en-in/rent-receipt-generator") |> html_response(200)
      options = html |> LazyHTML.from_document() |> LazyHTML.query("#stamp-select option")

      assert LazyHTML.attribute(options, "value") |> Enum.take(2) == [
               "",
               "system:india-rupee-one-revenue-stamp"
             ]

      assert LazyHTML.text(options) =~ "Empty box (placeholder only)"
      assert LazyHTML.text(options) =~ "India rupee one revenue stamp"
      assert LazyHTML.text(options) =~ "Landlord"
      refute html =~ "Somebody Else"
      refute html =~ "/uploads/#{theirs.path}"
      assert [_] = attrs(html, "#stamp-section", "id")
      assert [_] = attrs(html, "#stamp-save", "id")

      # a logged-in user has the upload open: nothing is locked, and there is nothing to sign up for
      assert [_] = attrs(html, "#stamp-open", "id")
      assert attrs(html, "#stamp-open", "disabled") == []
      assert attrs(html, "#stamp-signup", "id") == []
      assert [_] = attrs(html, "#stamp-dialog", "id")

      # a bill with no place for it in any design does not offer it
      fuel = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)
      assert attrs(fuel, "#stamp-section", "id") == []

      # a receipt that has one offers it in every country, with the title in the language of the page
      spanish = conn |> get(~p"/es-es/generador-de-recibo-de-alquiler") |> html_response(200)
      assert [_] = attrs(spanish, "#stamp-section", "id")
      assert spanish =~ "Sello fiscal"

      hindi = conn |> get(~p"/hi-in/rent-receipt-generator") |> html_response(200)
      assert hindi =~ "रेवेन्यू स्टैम्प"
    end

    test "the upload is on the receipt of every country for a logged-in user, as it is in India",
         %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      for path <- [
            "/en-in/rent-receipt-generator",
            "/en-us/rent-receipt-generator",
            "/en-gb/rent-receipt-generator",
            "/de-de/mietquittung-generator",
            "/ja-jp/rent-receipt-generator"
          ] do
        html = conn |> get(path) |> html_response(200)

        assert [_] = attrs(html, "#stamp-section", "id"), path
        assert [_] = attrs(html, "#stamp-open", "id"), path
        assert attrs(html, "#stamp-open", "disabled") == [], path
        assert [_] = attrs(html, "#stamp-dialog", "id"), path
      end
    end

    test "a design without the box keeps the choice on the page and says so, instead of hiding it",
         %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      schema = schema_of(conn, "/en-in/rent-receipt-generator")

      boxes = Map.new(schema["templates"], &{&1["id"], &1["stamp"]})
      assert boxes == %{"t1" => true, "t2" => true, "t4" => false}

      # the first design has the box: the choice is there, and says nothing
      html = conn |> get(~p"/en-in/rent-receipt-generator") |> html_response(200)
      assert [_] = attrs(html, "#stamp-section", "id")
      assert hd(attrs(html, "#stamp-note-design", "class")) =~ "hidden"

      # a document made with the design that has none: the choice and the upload are still there, with the reason
      document = document_fixture(scope, %{slug: "rent-receipt", template: "t4", data: %{}})

      html =
        conn |> get(~p"/en-in/rent-receipt-generator?from=#{document.id}") |> html_response(200)

      assert [_] = attrs(html, "#stamp-section", "id")
      assert [_] = attrs(html, "#stamp-select", "id")
      assert [_] = attrs(html, "#stamp-open", "id")
      assert attrs(html, "#stamp-open", "disabled") == []
      refute hd(attrs(html, "#stamp-note-design", "class")) =~ "hidden"
    end

    test "a visitor can choose a stamp of the site, but saving one of their own is locked", %{
      conn: conn
    } do
      html = conn |> get(~p"/en-in/rent-receipt-generator") |> html_response(200)

      assert [_] = attrs(html, "#stamp-select", "id")
      assert attrs(html, "#stamp-select", "disabled") == []
      # only the stamps of the site are on the page: no saved ones
      [stamps] = html |> attrs("#bill-app", "data-stamps") |> Enum.map(&Jason.decode!/1)
      assert Enum.all?(stamps, &String.starts_with?(&1["id"], "system:"))

      # the upload is there but locked, with the way to enable it; the form that saves a stamp is not on the page
      assert attrs(html, "#stamp-open", "disabled") == [""]
      assert attrs(html, "#stamp-signup", "href") == ["/users/register"]
      assert attrs(html, "#stamp-open", "aria-describedby") == ["stamp-signup"]
      assert attrs(html, "#stamp-dialog", "id") == []
      assert attrs(html, "#stamp-save", "id") == []
    end

    test "does not depend on where the visitor is: a Thai address on the page for India still has it",
         %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      html =
        conn
        |> put_req_header("cf-ipcountry", "TH")
        |> put_req_header("accept-language", "th-TH,th;q=0.9,en;q=0.8")
        |> get(~p"/en-in/rent-receipt-generator")
        |> html_response(200)

      assert [_] = attrs(html, "#stamp-section", "id")
      assert [_] = attrs(html, "#stamp-open", "id")
      assert attrs(html, "#stamp-open", "disabled") == []
    end

    test "a visitor is offered the stamp on every receipt that has a place for it, in every country, and on no other bill",
         %{conn: conn} do
      fuel = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)
      assert attrs(fuel, "#stamp-section", "id") == []
      assert attrs(fuel, "#stamp-signup", "id") == []

      for path <- [
            "/en-in/rent-receipt-generator",
            "/en-us/rent-receipt-generator",
            "/es-es/generador-de-recibo-de-alquiler",
            "/ja-jp/rent-receipt-generator"
          ] do
        html = conn |> get(path) |> html_response(200)

        assert [_] = attrs(html, "#stamp-section", "id"), path
        assert attrs(html, "#stamp-select", "disabled") == [], path
        assert attrs(html, "#stamp-open", "disabled") == [""], path
        assert attrs(html, "#stamp-signup", "href") == ["/users/register"], path
        assert attrs(html, "#stamp-dialog", "id") == [], path
      end
    end

    test "the stamp of an earlier document is chosen again", %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      saved = stamp_fixture(scope, %{name: "Landlord"})
      kept = document_fixture(scope, %{slug: "rent-receipt", data: %{}}, nil, nil, saved)

      default =
        document_fixture(
          scope,
          %{slug: "rent-receipt", data: %{}},
          nil,
          nil,
          {:system, "india-rupee-one-revenue-stamp"}
        )

      plain = document_fixture(scope, %{slug: "rent-receipt", data: %{}})

      for {doc, choice} <- [
            {kept, to_string(saved.id)},
            {default, "system:india-rupee-one-revenue-stamp"},
            {plain, ""}
          ] do
        html = conn |> get(~p"/en-in/rent-receipt-generator?from=#{doc.id}") |> html_response(200)
        assert attrs(html, "#bill-app", "data-stamp-choice") == [choice]
      end
    end

    test "a visitor has none: the choice is there but locked, with a way to sign up", %{
      conn: conn
    } do
      html = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)

      assert html =~ ~s(data-signatures="[]")
      assert attrs(html, "#bill-app", "data-signed-in") == ["false"]

      # it is on the page, as it is for a logged-in user, with nothing in it to choose
      assert [_] = attrs(html, "#signature-section", "id")
      assert attrs(html, "#signature-select option", "value") == [""]
      assert attrs(html, "#signature-select", "disabled") == [""]
      assert attrs(html, "#signature-open", "disabled") == [""]

      # ... with the way to enable it, and without the form that saves a signature
      assert attrs(html, "#signature-signup", "href") == ["/users/register"]
      assert attrs(html, "#signature-open", "aria-describedby") == ["signature-signup"]
      assert attrs(html, "#signature-dialog", "id") == []
      assert attrs(html, "#signature-save", "id") == []
    end

    test "a visitor's locked choice follows the design like a logged-in user's", %{conn: conn} do
      fuel = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)
      grocery = conn |> get(~p"/en-in/grocery-bill-generator") |> html_response(200)

      refute hd(attrs(fuel, "#signature-section", "class")) =~ "hidden"
      assert hd(attrs(grocery, "#signature-section", "class")) =~ "hidden"
    end

    test "the label that says to sign up is in the language of the page", %{conn: conn} do
      html = conn |> get(~p"/es-es/generador-de-factura-de-gasolina") |> html_response(200)

      assert attrs(html, "#signature-signup", "href") == ["/users/register"]
      assert html =~ "Regístrate para activarlo"
    end

    test "a logged-in user is told so", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      html = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)

      assert attrs(html, "#bill-app", "data-signed-in") == ["true"]
    end
  end

  describe "edit and regenerate" do
    defp earlier(scope, attrs \\ %{}, business \\ nil, signature \\ nil) do
      sample = "priv/bill_templates/fuel-bill/sample.json" |> File.read!() |> Jason.decode!()
      data = Map.put(sample, "station_name", "Edited Station")
      document_fixture(scope, Map.merge(%{data: data}, attrs), business, signature)
    end

    test "the form starts with the data of the earlier document", %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      doc = earlier(scope)

      html = conn |> get(~p"/en-in/fuel-bill-generator?from=#{doc.id}") |> html_response(200)

      assert html =~ "Edited Station"
      refute html =~ "Sunrise Fuel Station"
    end

    test "the business of the earlier document is named, so it can be selected again", %{
      conn: conn
    } do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      business = business_fixture(scope)
      doc = earlier(scope, %{}, business)

      html = conn |> get(~p"/en-in/fuel-bill-generator?from=#{doc.id}") |> html_response(200)

      assert html =~ ~s(data-business-id="#{business.id}")
    end

    test "the signature of the earlier document is named, and chosen in the select", %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      signature = signature_fixture(scope, %{name: "Owner"})
      signature_fixture(scope, %{name: "Manager"})
      doc = earlier(scope, %{}, nil, signature)

      html = conn |> get(~p"/en-in/fuel-bill-generator?from=#{doc.id}") |> html_response(200)

      assert attrs(html, "#bill-app", "data-signature-id") == [Integer.to_string(signature.id)]

      selected =
        html |> LazyHTML.from_document() |> LazyHTML.query("#signature-select option[selected]")

      assert LazyHTML.text(selected) =~ "Owner"
    end

    test "without a signature, there is no signature id on the page", %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      doc = earlier(scope)

      html = conn |> get(~p"/en-in/fuel-bill-generator?from=#{doc.id}") |> html_response(200)

      assert attrs(html, "#bill-app", "data-signature-id") == []
    end

    test "without a business, there is no business id on the page", %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      doc = earlier(scope)

      html = conn |> get(~p"/en-in/fuel-bill-generator?from=#{doc.id}") |> html_response(200)

      refute html =~ "data-business-id"
    end

    test "somebody else's document is ignored", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      doc = earlier(user_scope_fixture())

      html = conn |> get(~p"/en-in/fuel-bill-generator?from=#{doc.id}") |> html_response(200)

      assert html =~ "Sunrise Fuel Station"
      refute html =~ "Edited Station"
    end

    test "a document of another template is ignored", %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      doc = earlier(scope, %{slug: "rent-receipt"})

      html = conn |> get(~p"/en-in/fuel-bill-generator?from=#{doc.id}") |> html_response(200)

      refute html =~ "Edited Station"
    end

    test "nonsense in from= is ignored", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})

      assert conn |> get(~p"/en-in/fuel-bill-generator?from=abc") |> html_response(200) =~
               "Sunrise Fuel Station"

      assert conn |> get(~p"/en-in/fuel-bill-generator?from=999999999999") |> html_response(200) =~
               "Sunrise"
    end

    test "a visitor can't use it", %{conn: conn} do
      html = conn |> get(~p"/en-in/fuel-bill-generator?from=1") |> html_response(200)

      assert html =~ "Sunrise Fuel Station"
    end
  end

  describe "the country and the currency" do
    test "the page tells the script its country's own currency", %{conn: conn} do
      html = conn |> get(~p"/es-es/generador-de-factura-de-gasolina") |> html_response(200)

      assert attrs(html, "#bill-app", "data-own-currency") == ["EUR"]
      assert attrs(html, "#bill-app", "data-edit") == ["false"]
    end

    test "the dialog of the site (language, country, currency) has the currencies, with the country's own chosen",
         %{conn: conn} do
      html = conn |> get(~p"/es-es/generador-de-factura-de-gasolina") |> html_response(200)
      document = LazyHTML.from_document(html)

      for id <- ["#locale-menu-currency", "#footer-locale-currency"] do
        assert document |> LazyHTML.query("#{id} option[selected]") |> LazyHTML.attribute("value") ==
                 ["EUR"]

        assert document |> LazyHTML.query("#{id} option") |> Enum.count() == 8
      end

      assert document
             |> LazyHTML.query("#footer-locale-dialog[data-locale-dialog]")
             |> Enum.count() ==
               1
    end

    test "tells the preview which fonts to load", %{conn: conn} do
      html = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)
      assert [fonts] = attrs(html, "#bill-app", "data-fonts")
      assert Jason.decode!(fonts) == ["/fonts/NotoSans-Regular.ttf", "/fonts/NotoSans-Bold.ttf"]
    end

    test "a document made for another country opens with that country's form", %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      sample = "priv/bill_templates/fuel-bill/sample.json" |> File.read!() |> Jason.decode!()

      doc =
        document_fixture(scope, %{
          data: sample,
          options: %{"country" => "es", "currency" => "EUR"}
        })

      html = conn |> get("/en-in/fuel-bill-generator?from=#{doc.id}") |> html_response(200)

      assert attrs(html, "#bill-app", "data-edit") == ["true"]
      assert [region] = attrs(html, "#bill-app", "data-region") |> Enum.map(&Jason.decode!/1)
      assert region["country"] == "es" and region["currency"]["code"] == "EUR"

      assert [schema] = attrs(html, "#bill-app", "data-schema") |> Enum.map(&Jason.decode!/1)
      assert Enum.find(schema["fields"], &(&1["key"] == "tax_percent"))["rates"] == [0, 4, 10, 21]
    end
  end

  describe "the template select" do
    test "lists the designs of a bill, the first one chosen", %{conn: conn} do
      html = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)
      document = LazyHTML.from_document(html)

      assert document |> LazyHTML.query("#design-picker input") |> LazyHTML.attribute("value") ==
               ~w(t1 t2 t3 t4 t5 t6)

      assert document
             |> LazyHTML.query("#design-picker input[checked]")
             |> LazyHTML.attribute("value") == ["t1"]

      assert document |> LazyHTML.query("#design-picker") |> LazyHTML.text() =~ "Receipt"

      assert attrs(html, "#bill-app", "data-template") == ["t1"]
    end

    test "has a small picture of each design, from the thumbnail address", %{conn: conn} do
      html = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)

      assert attrs(html, "#design-picker img", "src") ==
               for(n <- 1..6, do: "/thumbnails/fuel-bill/t#{n}")
    end

    test "has the paper to choose for a design that is not a roll, and says why there is none for a roll",
         %{
           conn: conn
         } do
      sheet = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)
      options = sheet |> LazyHTML.from_document() |> LazyHTML.query("#paper-select option")

      assert LazyHTML.attribute(options, "value") == ["", "a4", "a5", "us-letter"]
      refute hd(attrs(sheet, "#paper-select", "class")) =~ "hidden"
      assert hd(attrs(sheet, "#paper-thermal", "class")) =~ "hidden"

      # fuel bill design 2 is made for a thermal printer
      [schema] = sheet |> attrs("#bill-app", "data-schema") |> Enum.map(&Jason.decode!/1)
      thermal = Map.new(schema["templates"], &{&1["id"], &1["thermal"]})

      assert thermal == %{
               "t1" => false,
               "t2" => true,
               "t3" => true,
               "t4" => true,
               "t5" => true,
               "t6" => true
             }
    end

    test "starts with the sheet of the document that is edited", %{conn: conn} do
      %{conn: conn, scope: scope} = register_and_log_in_user(%{conn: conn})
      doc = earlier(scope, %{options: %{"paper" => "a5"}})

      html = conn |> get(~p"/en-in/fuel-bill-generator?from=#{doc.id}") |> html_response(200)

      assert attrs(html, "#bill-app", "data-paper") == ["a5"]

      selected =
        html |> LazyHTML.from_document() |> LazyHTML.query("#paper-select option[selected]")

      assert LazyHTML.attribute(selected, "value") == ["a5"]
    end

    test "is there even when a bill has one template", %{conn: conn} do
      html = conn |> get(~p"/en-in/courier-receipt-generator") |> html_response(200)

      assert html
             |> LazyHTML.from_document()
             |> LazyHTML.query("#design-picker input")
             |> LazyHTML.attribute("value") == ["t1"]
    end

    test "has the names in the language of the page", %{conn: conn} do
      html = conn |> get(~p"/hi-in/fuel-bill-generator") |> html_response(200)

      assert html
             |> LazyHTML.from_document()
             |> LazyHTML.query("#design-picker")
             |> LazyHTML.text() =~ "पंप स्लिप"
    end
  end

  describe "the page of a bill" do
    test "puts the saved pictures after the form, and the advanced settings last", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())
      html = conn |> get(~p"/en-in/driver-salary-receipt-generator") |> html_response(200)
      position = fn id -> :binary.match(html, ~s(id="#{id}")) |> elem(0) end

      assert position.("design-picker") < position.("signature-rights")
      assert position.("signature-rights") < position.("stamp-rights")
      assert position.("stamp-rights") < position.("advanced-settings")
      assert position.("advanced-settings") < position.("paper-select")
    end

    test "offers six designs to a row on a wide screen, and a box to confirm the rights", %{
      conn: conn
    } do
      conn = log_in_user(conn, user_fixture())
      # a bill that has a place for a revenue stamp: the others have no stamp dialog
      html = conn |> get(~p"/en-in/rent-receipt-generator") |> html_response(200)
      doc = LazyHTML.from_document(html)

      assert LazyHTML.query(doc, "#design-picker.sm\\:grid-cols-6") |> Enum.count() == 1
      assert LazyHTML.query(doc, "#signature-rights[type=checkbox]") |> Enum.count() == 1
      assert LazyHTML.query(doc, "#stamp-rights[type=checkbox]") |> Enum.count() == 1
    end
  end

  describe "saving a new signature or stamp" do
    test "is done in a dialog that a button opens, not in an expanding section", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())

      # a bill that has a place for a signature and for a revenue stamp
      doc =
        conn
        |> get(~p"/en-in/rent-receipt-generator")
        |> html_response(200)
        |> LazyHTML.from_document()

      for kind <- ["signature", "stamp"] do
        assert LazyHTML.query(doc, "button##{kind}-open[data-dialog-open=#{kind}-dialog]")
               |> Enum.count() == 1

        assert LazyHTML.query(doc, "dialog##{kind}-dialog ##{kind}-file[type=file]")
               |> Enum.count() == 1

        assert LazyHTML.query(doc, "dialog##{kind}-dialog ##{kind}-rights[type=checkbox]")
               |> Enum.count() == 1

        assert LazyHTML.query(doc, "dialog##{kind}-dialog ##{kind}-save") |> Enum.count() == 1
        assert LazyHTML.query(doc, "details##{kind}-new") |> Enum.count() == 0
      end
    end
  end

  describe "the signatures of a bill that has two" do
    test "each section says whose it is, and each select has a + button for a new one", %{
      conn: conn
    } do
      conn = log_in_user(conn, user_fixture())

      doc =
        conn
        |> get(~p"/en-in/driver-salary-receipt-generator")
        |> html_response(200)
        |> LazyHTML.from_document()

      text = fn selector ->
        doc |> LazyHTML.query(selector) |> LazyHTML.text() |> String.trim()
      end

      assert text.("label[for=signature-select]") == "Employee Signature"
      assert text.("label[for=driver-signature-select]") == "Driver Signature"

      for id <- ["signature-open", "driver-signature-open", "stamp-open"] do
        assert LazyHTML.query(doc, "button##{id}[data-dialog-open]") |> Enum.count() == 1
        assert LazyHTML.query(doc, "button##{id}[disabled]") |> Enum.count() == 0
      end
    end

    test "a visitor sees each of them locked, with the name of its signer and a way to sign up",
         %{
           conn: conn
         } do
      salary =
        conn
        |> get(~p"/en-in/driver-salary-receipt-generator")
        |> html_response(200)
        |> LazyHTML.from_document()

      voucher =
        conn
        |> get(~p"/en-in/cash-voucher-generator")
        |> html_response(200)
        |> LazyHTML.from_document()

      count = fn doc, selector -> doc |> LazyHTML.query(selector) |> Enum.count() end

      # the driver salary receipt: two signatures and the revenue stamp
      for id <- ["signature", "driver-signature"] do
        assert count.(salary, "select##{id}-select[disabled]") == 1
        assert count.(salary, "button##{id}-open[disabled]") == 1
        assert count.(salary, "a##{id}-signup[href='/users/register']") == 1
      end

      assert count.(salary, "button#stamp-open[disabled]") == 1
      assert count.(salary, "a#stamp-signup[href='/users/register']") == 1
      assert count.(salary, "select#stamp-select[disabled]") == 0

      # the cash voucher: three signatures, named in the words of the bill
      assert count.(voucher, "select#extra-signature-select-signature_3[disabled]") == 1
      assert count.(voucher, "button#extra-signature-open-signature_3[disabled]") == 1
      assert count.(voucher, "a#extra-signature-signup-signature_3[href='/users/register']") == 1

      assert voucher
             |> LazyHTML.query("label[for=extra-signature-select-signature_3]")
             |> LazyHTML.text()
             |> String.trim() == "Approved by"

      assert count.(voucher, "[data-extra-signature=signature_4]") == 0
    end

    test "a cash voucher has a signature select for each of its three signers, with their names",
         %{
           conn: conn
         } do
      conn = log_in_user(conn, user_fixture())

      doc =
        conn
        |> get(~p"/en-in/cash-voucher-generator")
        |> html_response(200)
        |> LazyHTML.from_document()

      text = fn selector ->
        doc |> LazyHTML.query(selector) |> LazyHTML.text() |> String.trim()
      end

      assert text.("label[for=signature-select]") == "Prepared by"
      assert text.("label[for=driver-signature-select]") == "Checked by"
      assert text.("label[for=extra-signature-select-signature_3]") == "Approved by"

      assert LazyHTML.query(doc, "button#extra-signature-open-signature_3[data-dialog-open]")
             |> Enum.count() == 1

      assert LazyHTML.query(doc, "[data-extra-signature=signature_4]") |> Enum.count() == 0
    end

    test "a bill with one signature calls it Signature", %{conn: conn} do
      conn = log_in_user(conn, user_fixture())

      doc =
        conn
        |> get(~p"/en-in/fuel-bill-generator")
        |> html_response(200)
        |> LazyHTML.from_document()

      assert doc
             |> LazyHTML.query("label[for=signature-select]")
             |> LazyHTML.text()
             |> String.trim() == "Signature"
    end
  end

  describe "the sections of a bill in its own words" do
    defp schema_of(conn, path) do
      [json] = conn |> get(path) |> html_response(200) |> attrs("#bill-app", "data-schema")
      Jason.decode!(json)
    end

    test "name the parties of the bill, in the language of the page", %{conn: conn} do
      en = schema_of(conn, "/en-in/rent-receipt-generator")

      assert %{"business" => "Landlord", "customer" => "Tenant", "document" => "Rent Period"} =
               en["groups"]

      hi = schema_of(conn, "/hi-in/rent-receipt-generator")
      assert hi["groups"]["customer"] != "Tenant"
      assert hi["groups"]["customer"] != ""
    end

    test "say which sections a user may save and pick again", %{conn: conn} do
      assert schema_of(conn, "/en-in/driver-salary-receipt-generator")["saved_groups"] ==
               ["business", "customer", "details"]

      assert schema_of(conn, "/en-in/rent-receipt-generator")["saved_groups"] == ["customer"]

      assert schema_of(conn, "/en-in/fuel-bill-generator")["saved_groups"] == [
               "customer",
               "details"
             ]
    end

    test "have field names in Title Case", %{conn: conn} do
      labels =
        conn
        |> schema_of("/en-in/fuel-bill-generator")
        |> Map.fetch!("fields")
        |> Enum.map(& &1["label"])

      assert "Fuel Station Name" in labels
      assert "Bill Number" in labels
    end
  end

  describe "the sections of the form" do
    @groups ~w(business registration document customer items details charges payment additional)

    test "every field of every bill is in a section the form knows" do
      for %{"slug" => slug} <- QuickSlips.Templates.list(),
          {:ok, schema} = QuickSlips.Templates.get(slug),
          field <- schema["fields"] do
        assert field["group"] in @groups, "#{slug}: #{field["key"]}"
      end
    end

    test "the page has a title for each section", %{conn: conn} do
      html = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)
      [i18n] = attrs(html, "#bill-app", "data-i18n") |> Enum.map(&Jason.decode!/1)

      for group <- @groups, do: assert(Map.has_key?(i18n, "group_" <> group), group)
    end
  end
end
