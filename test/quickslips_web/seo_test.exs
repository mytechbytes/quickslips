defmodule QuickSlipsWeb.SeoTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Locales
  alias QuickSlips.Templates
  alias QuickSlipsWeb.Endpoint
  alias QuickSlipsWeb.Seo

  defp graph(%{json_ld: json}), do: Jason.decode!(json)["@graph"]
  defp node(graph, type), do: Enum.find(graph, &(&1["@type"] == type))

  defp bill(slug, code) do
    locale = Locales.fetch!(code)
    {:ok, schema} = Templates.get(slug, locale)
    {locale, schema}
  end

  describe "home/1" do
    test "says where the catalogue lives and where it is in other languages" do
      seo = Seo.home(Locales.fetch!("hi-in"))

      assert seo.canonical_url == Endpoint.url() <> "/hi-in"
      assert length(seo.alternates) == length(Locales.live()) + 1
      assert {"hi-IN", Endpoint.url() <> "/hi-in"} in seo.alternates
      assert {"x-default", Endpoint.url() <> "/en-in"} in seo.alternates
    end

    test "describes the site and its organisation, in the language of the page" do
      nodes = Locales.fetch!("es-es") |> Seo.home() |> graph()

      assert %{
               "url" => url,
               "name" => "QuickSlips",
               "inLanguage" => "es-ES",
               "description" => "Crea facturas y recibos en PDF en segundos."
             } = node(nodes, "WebSite")

      assert url == Endpoint.url() <> "/es-es"

      assert %{"name" => "QuickSlips", "url" => _, "logo" => logo} = node(nodes, "Organization")
      assert logo == Endpoint.url() <> "/images/logo-mark-512.png"
    end
  end

  describe "bill/2" do
    test "says where the page lives and where it is in other languages" do
      {locale, schema} = bill("fuel-bill", "es-es")
      seo = Seo.bill(locale, schema)

      assert seo.canonical_url == Endpoint.url() <> "/es-es/generador-de-factura-de-gasolina"
      assert {"en-IN", Endpoint.url() <> "/en-in/fuel-bill-generator"} in seo.alternates
      assert {"x-default", Endpoint.url() <> "/en-in/fuel-bill-generator"} in seo.alternates
    end

    test "describes the page as a free web application" do
      {locale, schema} = bill("fuel-bill", "en-in")
      nodes = locale |> Seo.bill(schema) |> graph()

      assert %{
               "name" => "Fuel Bill Generator",
               "description" => description,
               "url" => url,
               "inLanguage" => "en-IN",
               "applicationCategory" => "BusinessApplication",
               "isAccessibleForFree" => true,
               "offers" => %{"price" => "0", "priceCurrency" => "INR"}
             } = node(nodes, "WebApplication")

      assert description == schema["description"]
      assert url == Endpoint.url() <> "/en-in/fuel-bill-generator"
    end

    test "the currency of the offer is the country's" do
      {locale, schema} = bill("fuel-bill", "pt-br")

      assert %{"offers" => %{"priceCurrency" => "BRL"}} =
               locale |> Seo.bill(schema) |> graph() |> node("WebApplication")
    end

    test "has a breadcrumb from the catalogue to the page" do
      {locale, schema} = bill("rent-receipt", "de-de")

      assert %{
               "itemListElement" => [
                 %{"position" => 1, "name" => "QuickSlips", "item" => home},
                 %{"position" => 2, "name" => title, "item" => page}
               ]
             } = locale |> Seo.bill(schema) |> graph() |> node("BreadcrumbList")

      assert home == Endpoint.url() <> "/de-de"
      assert title == schema["title"]
      assert page == Endpoint.url() <> "/de-de/" <> schema["public_slug"]
    end

    test "has the questions of the page, as the page shows them" do
      {locale, schema} = bill("fuel-bill", "fr-fr")

      assert %{"mainEntity" => entities} =
               locale |> Seo.bill(schema) |> graph() |> node("FAQPage")

      assert Enum.map(entities, &{&1["name"], &1["acceptedAnswer"]["text"]}) ==
               Enum.map(schema["faq"], &{&1["q"], &1["a"]})

      assert Enum.all?(
               entities,
               &(&1["@type"] == "Question" and &1["acceptedAnswer"]["@type"] == "Answer")
             )
    end

    test "has no FAQPage for a page without questions" do
      {locale, schema} = bill("fuel-bill", "en-in")
      nodes = locale |> Seo.bill(Map.put(schema, "faq", [])) |> graph()

      assert node(nodes, "FAQPage") == nil
      assert node(nodes, "WebApplication")
    end

    test "nothing in the text can close the script tag it is written into" do
      {locale, schema} = bill("fuel-bill", "en-in")
      evil = "</script><script>alert(1)</script> & <!--"
      seo = Seo.bill(locale, %{schema | "title" => evil, "faq" => [%{"q" => evil, "a" => evil}]})

      # `<` is written as \u003C, so there is no `</script>` and no `<!--` in it, whatever a text says
      refute seo.json_ld =~ "<"
      # ... and it reads back as it was
      assert %{"name" => ^evil} = seo |> graph() |> node("WebApplication")
    end
  end

  describe "pages/0" do
    test "is a page for each live locale and each bill in it, each with the locales that have it" do
      pages = Seo.pages()

      bills = Enum.sum(for locale <- Locales.live(), do: length(Templates.list(locale)))
      assert length(pages) == length(Locales.live()) + bills

      assert Enum.all?(
               pages,
               &(&1.alternates != [] and String.starts_with?(&1.url, Endpoint.url()))
             )
    end
  end
end
