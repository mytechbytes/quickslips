defmodule QuickSlipsWeb.SeoPagesTest do
  use QuickSlipsWeb.ConnCase

  alias QuickSlips.Locales
  alias QuickSlipsWeb.Endpoint

  # What a search engine or a link preview reads of a page: the `meta` and `link` tags of its head, its structured
  # data, and the words under the form.

  defp document(html), do: LazyHTML.from_document(html)

  defp content(doc, selector),
    do: doc |> LazyHTML.query(selector) |> LazyHTML.attribute("content")

  defp texts(doc, selector),
    do: doc |> LazyHTML.query(selector) |> Enum.map(&LazyHTML.text/1) |> Enum.map(&String.trim/1)

  defp json_ld(doc) do
    [json] =
      doc |> LazyHTML.query("script[type='application/ld+json']") |> Enum.map(&LazyHTML.text/1)

    Jason.decode!(json)["@graph"]
  end

  defp page(conn, path), do: conn |> get(path) |> html_response(200) |> document()

  describe "the Open Graph and Twitter tags of a bill's page" do
    setup %{conn: conn}, do: %{doc: page(conn, ~p"/en-in/fuel-bill-generator")}

    test "say what the page is, where it lives and in which language", %{doc: doc} do
      assert content(doc, "meta[property='og:type']") == ["website"]
      assert content(doc, "meta[property='og:site_name']") == ["QuickSlips"]
      assert content(doc, "meta[property='og:title']") == ["Fuel Bill Generator"]
      assert content(doc, "meta[property='og:locale']") == ["en_IN"]

      [description] = content(doc, "meta[name=description]")
      assert content(doc, "meta[property='og:description']") == [description]
      assert description =~ "Generate a clean fuel bill"

      canonical = doc |> LazyHTML.query("link[rel=canonical]") |> LazyHTML.attribute("href")
      assert canonical == [Endpoint.url() <> "/en-in/fuel-bill-generator"]
      assert content(doc, "meta[property='og:url']") == canonical
    end

    test "name the other locales of the page, but not the page's own and not x-default", %{
      doc: doc
    } do
      others = content(doc, "meta[property='og:locale:alternate']")

      assert length(others) == length(Locales.live()) - 1
      assert "hi_IN" in others
      assert "es_ES" in others
      refute "en_IN" in others
      refute Enum.any?(others, &(&1 =~ "default"))
    end

    test "carry a picture with an absolute address, and a Twitter card that says the same", %{
      doc: doc
    } do
      image = Endpoint.url() <> "/images/logo-mark-512.png"

      assert content(doc, "meta[property='og:image']") == [image]
      assert content(doc, "meta[property='og:image:alt']") == ["QuickSlips"]
      assert content(doc, "meta[name='twitter:card']") == ["summary"]
      assert content(doc, "meta[name='twitter:image']") == [image]
      assert content(doc, "meta[name='twitter:title']") == ["Fuel Bill Generator"]

      assert content(doc, "meta[name='twitter:description']") ==
               content(doc, "meta[property='og:description']")
    end

    test "are in the language of the page", %{conn: conn} do
      doc = page(conn, ~p"/es-es/generador-de-factura-de-gasolina")

      assert content(doc, "meta[property='og:title']") == ["Generador de Factura de Gasolina"]
      assert content(doc, "meta[property='og:locale']") == ["es_ES"]

      assert content(doc, "meta[property='og:description']") !=
               content(
                 page(conn, ~p"/en-in/fuel-bill-generator"),
                 "meta[property='og:description']"
               )
    end
  end

  describe "the head of a catalogue" do
    test "has the same tags and describes the site", %{conn: conn} do
      doc = page(conn, ~p"/hi-in")

      assert content(doc, "meta[property='og:type']") == ["website"]
      assert content(doc, "meta[property='og:url']") == [Endpoint.url() <> "/hi-in"]
      assert content(doc, "meta[property='og:locale']") == ["hi_IN"]

      assert content(doc, "meta[property='og:image']") == [
               Endpoint.url() <> "/images/logo-mark-512.png"
             ]

      nodes = json_ld(doc)
      assert Enum.any?(nodes, &(&1["@type"] == "WebSite" and &1["inLanguage"] == "hi-IN"))
      assert Enum.any?(nodes, &(&1["@type"] == "Organization"))
    end
  end

  describe "a page that is not public" do
    test "has no link preview and no structured data: nothing says where it lives", %{conn: conn} do
      doc = page(conn, ~p"/users/log-in")

      assert content(doc, "meta[property^='og:']") == []
      assert content(doc, "meta[name^='twitter:']") == []
      assert doc |> LazyHTML.query("script[type='application/ld+json']") |> Enum.count() == 0
      assert doc |> LazyHTML.query("link[rel=canonical]") |> Enum.count() == 0
    end
  end

  describe "the structured data of a bill's page" do
    test "is one JSON document with the application, its breadcrumb, its questions and the organisation",
         %{conn: conn} do
      nodes = conn |> page(~p"/en-in/rent-receipt-generator") |> json_ld()

      assert Enum.map(nodes, & &1["@type"]) == [
               "WebApplication",
               "BreadcrumbList",
               "FAQPage",
               "Organization"
             ]
    end

    test "has the questions and answers that the page shows, word for word", %{conn: conn} do
      doc = page(conn, ~p"/de-de/mietquittung-generator")

      [faq] = json_ld(doc) |> Enum.filter(&(&1["@type"] == "FAQPage"))
      from_data = Enum.map(faq["mainEntity"], &{&1["name"], &1["acceptedAnswer"]["text"]})

      questions = texts(doc, "#bill-faq h3")
      answers = texts(doc, "#bill-faq h3 + p")

      assert questions != []
      assert from_data == Enum.zip(questions, answers)
    end
  end

  describe "the words under the form" do
    test "are an intro that says what the bill is, and the questions people ask", %{conn: conn} do
      doc = page(conn, ~p"/en-in/fuel-bill-generator")

      assert texts(doc, "#bill-intro h2") == ["Fuel Bill"]
      assert [intro] = texts(doc, "#bill-intro p")
      assert intro =~ "A fuel bill is the receipt a petrol pump gives"

      assert texts(doc, "#bill-faq > h2") == ["Frequently asked questions"]
      questions = texts(doc, "#bill-faq h3")
      assert hd(questions) == "How do I use the Fuel Bill Generator?"
      assert "Is this an official document?" in questions
      assert length(questions) >= 5
    end

    test "say what is true of this bill: its designs and what it needs", %{conn: conn} do
      doc = page(conn, ~p"/en-in/fuel-bill-generator")
      [how, required | _] = texts(doc, "#bill-faq h3 + p")

      assert how =~ "Choose one of the 6 designs: Receipt, Pump slip, Thermal"
      assert required =~ "You need: Fuel Station Name, Bill Number, Date, Fuel Type"
    end

    test "ask about the tax only where the bill has one", %{conn: conn} do
      india = conn |> page(~p"/en-in/fuel-bill-generator") |> texts("#bill-faq h3")
      spain = conn |> page(~p"/es-es/generador-de-factura-de-gasolina") |> texts("#bill-faq h3")

      # The fuel bill has no tax in India, and has IVA, already in the price, in Spain.
      refute Enum.any?(india, &(&1 =~ "tax"))
      assert "¿Calcula el impuesto (IVA)?" in spain
    end

    test "are in the language of the page", %{conn: conn} do
      for {path, heading, first} <- [
            {~p"/es-es/generador-de-factura-de-gasolina", "Preguntas frecuentes",
             "¿Cómo uso el Generador de Factura de Gasolina?"},
            {~p"/hi-in/fuel-bill-generator", "अक्सर पूछे जाने वाले प्रश्न", "पेट्रोल बिल जनरेटर का उपयोग कैसे करें?"},
            {~p"/ja-jp/fuel-bill-generator", "よくある質問", "「給油レシート作成」の使い方を教えてください。"},
            {~p"/fr-fr/generateur-de-facture-carburant", "Questions fréquentes",
             "Comment utiliser le Générateur de facture carburant ?"}
          ] do
        doc = page(conn, path)

        assert texts(doc, "#bill-faq > h2") == [heading], path
        assert hd(texts(doc, "#bill-faq h3")) == first, path
      end
    end

    test "are also there for a logged-in user", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      doc = page(conn, ~p"/en-in/fuel-bill-generator")

      assert texts(doc, "#bill-intro p") != []
      assert texts(doc, "#bill-faq h3") != []
    end

    test "do not travel to the script: the form needs no words that are for the reader", %{
      conn: conn
    } do
      html = conn |> get(~p"/en-in/fuel-bill-generator") |> html_response(200)

      [schema] =
        html |> document() |> LazyHTML.query("#bill-app") |> LazyHTML.attribute("data-schema")

      refute Map.has_key?(Jason.decode!(schema), "intro")
      refute Map.has_key?(Jason.decode!(schema), "faq")
    end

    test "the questions about signatures are only on a bill that has a place to sign", %{
      conn: conn
    } do
      signed = conn |> page(~p"/en-in/fuel-bill-generator") |> texts("#bill-faq h3")
      unsigned = conn |> page(~p"/en-in/grocery-bill-generator") |> texts("#bill-faq h3")

      assert "Can I add my signature?" in signed
      refute "Can I add my signature?" in unsigned
    end
  end
end
