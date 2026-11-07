defmodule QuickSlipsWeb.TemplateControllerTest do
  use QuickSlipsWeb.ConnCase

  import QuickSlips.AccountsFixtures
  import QuickSlips.BusinessesFixtures
  import QuickSlips.DocumentsFixtures

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
      html = conn |> get(~p"/en-in/rent-receipt-generator?from=3") |> html_response(200)
      base = QuickSlipsWeb.Endpoint.url()

      assert attrs(html, "link[rel=canonical]", "href") == [
               "#{base}/en-in/rent-receipt-generator"
             ]

      assert attrs(html, "link[rel=alternate]", "hreflang") ==
               ["en-IN", "en-US", "en-GB", "en-CA", "x-default"]
    end

    test "a bill that is not in the language of the locale is a 404, not English under another address",
         %{conn: conn} do
      assert_error_sent 404, fn -> get(conn, ~p"/hi-in/rent-receipt-generator") end
      assert_error_sent 404, fn -> get(conn, ~p"/es-es/rent-receipt-generator") end
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
      assert html =~ "&quot;signature_url&quot;:null"
    end

    test "a visitor gets an empty list", %{conn: conn} do
      html = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)
      assert html =~ ~s(data-businesses="[]")
    end
  end

  describe "edit and regenerate" do
    defp earlier(scope, attrs \\ %{}, business \\ nil) do
      sample = "priv/bill_templates/fuel-bill/sample.json" |> File.read!() |> Jason.decode!()
      data = Map.put(sample, "station_name", "Edited Station")
      document_fixture(scope, Map.merge(%{data: data}, attrs), business)
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

      assert document |> LazyHTML.query("#template-select option") |> LazyHTML.attribute("value") ==
               ~w(t1 t2 t3 t4 t5 t6)

      assert document |> LazyHTML.query("#template-select option[selected]") |> LazyHTML.text() =~
               "Receipt"

      assert attrs(html, "#bill-app", "data-template") == ["t1"]
    end

    test "is there even when a bill has one template", %{conn: conn} do
      html = conn |> get(~p"/en-in/rent-receipt-generator") |> html_response(200)

      assert html
             |> LazyHTML.from_document()
             |> LazyHTML.query("#template-select option")
             |> LazyHTML.attribute("value") == ["t1"]
    end

    test "has the names in the language of the page", %{conn: conn} do
      html = conn |> get(~p"/hi-in/fuel-bill-generator") |> html_response(200)

      assert html
             |> LazyHTML.from_document()
             |> LazyHTML.query("#template-select option")
             |> LazyHTML.text() =~ "पंप स्लिप"
    end
  end

  describe "the sections of the form" do
    @groups ~w(business registration document customer items details charges payment)

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
