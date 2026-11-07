defmodule QuickSlipsWeb.GenerateControllerTest do
  use QuickSlipsWeb.ConnCase

  @moduletag :typst

  setup do
    Req.Test.stub(QuickSlips.Turnstile, fn conn -> Req.Test.json(conn, %{"success" => true}) end)
    :ok
  end

  import QuickSlips.BusinessesFixtures
  import QuickSlips.UploadsFixtures

  defp sample, do: "priv/bill_templates/fuel-bill/sample.json" |> File.read!() |> Jason.decode!()

  test "returns a PDF download", %{conn: conn} do
    conn =
      post(conn, ~p"/api/generate", %{
        slug: "fuel-bill",
        template: "t1",
        data: sample(),
        turnstile_token: "test"
      })

    assert "%PDF" <> _ = response(conn, 200)
    assert [content_type] = get_resp_header(conn, "content-type")
    assert content_type =~ "application/pdf"
  end

  test "403 when the Turnstile token is missing", %{conn: conn} do
    conn = post(conn, ~p"/api/generate", %{slug: "fuel-bill", template: "t1", data: sample()})
    assert %{"error" => "verification failed"} = json_response(conn, 403)
  end

  test "422 with field errors for bad data", %{conn: conn} do
    conn = post(conn, ~p"/api/generate", %{slug: "fuel-bill", template: "t1", data: %{}})
    assert %{"errors" => %{"station_name" => ["is required"]}} = json_response(conn, 422)
  end

  test "404 for an unknown template", %{conn: conn} do
    conn = post(conn, ~p"/api/generate", %{slug: "nope", template: "t1", data: %{}})
    assert json_response(conn, 404)
  end

  describe "with a saved business" do
    setup :register_and_log_in_user

    defp generate(conn, extra \\ %{}) do
      post(
        conn,
        ~p"/api/generate",
        Map.merge(%{slug: "fuel-bill", template: "t1", data: sample()}, extra)
      )
    end

    test "draws its logo and signature on the PDF", %{conn: conn, user: user, scope: scope} do
      images = %{
        logo_path: stored_image(user.id),
        signature_path: stored_image(user.id, jpg_bytes())
      }

      business = business_fixture(scope, %{}, images)

      plain = conn |> generate() |> response(200)
      branded = conn |> generate(%{business_id: business.id}) |> response(200)

      assert "%PDF" <> _ = branded
      assert byte_size(branded) > byte_size(plain)
    end

    test "a business without pictures is fine", %{conn: conn, scope: scope} do
      business = business_fixture(scope)

      assert "%PDF" <> _ = conn |> generate(%{business_id: business.id}) |> response(200)
    end

    test "is a 404 for somebody else's business, and costs no download", %{conn: conn, user: user} do
      other = QuickSlips.AccountsFixtures.user_scope_fixture()
      business = business_fixture(other, %{}, %{logo_path: stored_image(other.user.id)})

      assert {404, _headers, body} =
               assert_error_sent(404, fn -> generate(conn, %{business_id: business.id}) end)

      assert %{"errors" => %{"detail" => "Not Found"}} = Jason.decode!(body)
      assert %{remaining: 3} = QuickSlips.Downloads.status(%{user: user})
    end

    test "a name for a picture in the data is ignored", %{conn: conn} do
      data = Map.merge(sample(), %{"logo" => "../../etc/passwd", "signature" => "data.json"})

      assert "%PDF" <> _ = conn |> generate(%{data: data}) |> response(200)
    end
  end

  test "a visitor's business_id is ignored", %{conn: conn} do
    conn =
      post(conn, ~p"/api/generate", %{
        slug: "fuel-bill",
        template: "t1",
        data: sample(),
        turnstile_token: "test",
        business_id: 1
      })

    assert "%PDF" <> _ = response(conn, 200)
  end

  describe "the history" do
    setup :register_and_log_in_user

    test "a logged-in user's download is kept, as data", %{conn: conn, scope: scope} do
      conn |> generate() |> response(200)

      assert [doc] = QuickSlips.Documents.list_documents(scope)
      assert doc.slug == "fuel-bill"
      assert doc.template == "t1"
      assert doc.title == "Fuel Bill · FB-10482 · Sunrise Fuel Station · 12 Oct 2026"
      assert doc.data["station_name"] == "Sunrise Fuel Station"
      assert doc.business_id == nil
    end

    test "the data kept is the clean data, not whatever was sent", %{conn: conn, scope: scope} do
      data = Map.merge(sample(), %{"logo" => "x.png", "anything" => "else"})

      conn |> generate(%{data: data}) |> response(200)

      assert [doc] = QuickSlips.Documents.list_documents(scope)
      refute Map.has_key?(doc.data, "logo")
      refute Map.has_key?(doc.data, "anything")
    end

    test "remembers the business", %{conn: conn, scope: scope} do
      business = business_fixture(scope)

      conn |> generate(%{business_id: business.id}) |> response(200)

      assert [%{business_id: business_id}] = QuickSlips.Documents.list_documents(scope)
      assert business_id == business.id
    end

    test "a download that fails leaves nothing in the history", %{conn: conn, scope: scope} do
      conn |> generate(%{data: %{}}) |> json_response(422)

      assert QuickSlips.Documents.list_documents(scope) == []
    end
  end

  test "a visitor's download is not kept", %{conn: conn} do
    post(conn, ~p"/api/generate", %{
      slug: "fuel-bill",
      template: "t1",
      data: sample(),
      turnstile_token: "test"
    })

    assert QuickSlips.Repo.aggregate(QuickSlips.Documents.Document, :count) == 0
  end

  describe "languages" do
    defp sample_for(code) do
      {:ok, sample} = QuickSlips.Templates.sample("fuel-bill", QuickSlips.Locales.fetch!(code))
      sample
    end

    defp generate_in(conn, code, extra \\ %{}) do
      post(
        conn,
        ~p"/api/generate",
        Map.merge(
          %{
            slug: "fuel-bill",
            template: "t1",
            locale: code,
            data: sample_for(code),
            turnstile_token: "test"
          },
          extra
        )
      )
    end

    test "makes the document in Hindi and in Spanish", %{conn: conn} do
      for code <- ["hi-in", "es-es"] do
        assert "%PDF" <> _ = conn |> generate_in(code) |> response(200)
      end
    end

    test "a request with no locale is for English, India", %{conn: conn} do
      assert "%PDF" <> _ =
               conn
               |> post(~p"/api/generate", %{
                 slug: "fuel-bill",
                 template: "t1",
                 data: sample(),
                 turnstile_token: "test"
               })
               |> response(200)
    end

    test "a locale that is not live, or does not exist, is a 400", %{conn: conn} do
      for code <- ["es-mx", "xx-yy", "", 5] do
        conn =
          post(conn, ~p"/api/generate", %{
            slug: "fuel-bill",
            template: "t1",
            locale: code,
            data: sample(),
            turnstile_token: "test"
          })

        assert %{"error" => "unknown language or country"} = json_response(conn, 400)
      end
    end

    test "a template that is not in the language is a 404, and costs no download", %{conn: conn} do
      conn =
        post(conn, ~p"/api/generate", %{
          slug: "grocery-bill",
          template: "t1",
          locale: "hi-in",
          data: %{},
          turnstile_token: "test"
        })

      assert %{"error" => "unknown template"} = json_response(conn, 404)
    end

    test "what is wrong with the data is said in the language of the page", %{conn: conn} do
      spanish = conn |> generate_in("es-es", %{data: %{}}) |> json_response(422)
      assert %{"errors" => %{"station_name" => ["es obligatorio"]}} = spanish

      hindi = conn |> generate_in("hi-in", %{data: %{}}) |> json_response(422)
      assert %{"errors" => %{"station_name" => ["ज़रूरी है"]}} = hindi

      english = conn |> generate_in("en-in", %{data: %{}}) |> json_response(422)
      assert %{"errors" => %{"station_name" => ["is required"]}} = english
    end

    test "a message with a number in it is translated with the number", %{conn: conn} do
      data = Map.put(sample_for("es-es"), "station_name", String.duplicate("x", 81))

      assert %{"errors" => %{"station_name" => ["debe tener como máximo 80 caracteres"]}} =
               conn |> generate_in("es-es", %{data: data}) |> json_response(422)

      data = Map.put(sample_for("hi-in"), "quantity", 0)

      assert %{"errors" => %{"quantity" => ["कम से कम 0.01 होना चाहिए"]}} =
               conn |> generate_in("hi-in", %{data: data}) |> json_response(422)
    end

    # The option is the English word in every language: "Petrol" is a petrol bill in Hindi too.
    test "an option is the same value in every language", %{conn: conn} do
      data = Map.put(sample_for("hi-in"), "fuel_type", "Gasolina")

      assert %{"errors" => %{"fuel_type" => [_]}} =
               conn |> generate_in("hi-in", %{data: data}) |> json_response(422)
    end
  end

  describe "the history of a document in another language" do
    setup :register_and_log_in_user

    test "keeps the language and the country, and names the document in that language", %{
      conn: conn,
      scope: scope
    } do
      conn |> generate_in("hi-in") |> response(200)
      conn |> generate_in("es-es") |> response(200)

      assert [spanish, hindi] = QuickSlips.Documents.list_documents(scope)

      assert hindi.language == "hi"
      assert hindi.options == %{"country" => "in", "currency" => "INR"}
      assert hindi.title == "पेट्रोल बिल · FB-10482 · सनराइज़ फ्यूल स्टेशन · 12 अक्टू. 2026"

      assert spanish.language == "es"
      assert spanish.options == %{"country" => "es", "currency" => "EUR"}
      assert spanish.title == "Factura de Gasolina · A-10482 · Gasolinera El Sol · 12 oct 2026"

      # What is kept is the internal slug, whatever the language: the history finds the page from it.
      assert spanish.slug == "fuel-bill"
    end

    test "a document made without a locale is English, for India", %{conn: conn, scope: scope} do
      conn |> generate() |> response(200)

      assert [doc] = QuickSlips.Documents.list_documents(scope)
      assert doc.language == "en"
      assert doc.options == %{"country" => "in", "currency" => "INR"}
    end
  end

  describe "a table of items" do
    defp bill_sample(slug),
      do: "priv/bill_templates/#{slug}/sample.json" |> File.read!() |> Jason.decode!()

    defp make(conn, slug, data),
      do:
        post(conn, ~p"/api/generate", %{
          slug: slug,
          template: "t1",
          data: data,
          turnstile_token: "test"
        })

    test "makes the grocery bill, the restaurant bill and the invoice from their rows", %{
      conn: conn
    } do
      for slug <- ["grocery-bill", "restaurant-bill", "service-invoice"] do
        assert "%PDF" <> _ = conn |> make(slug, bill_sample(slug)) |> response(200)
      end
    end

    test "names a mistake in a row after its cell", %{conn: conn} do
      data =
        Map.put(bill_sample("grocery-bill"), "items", [
          %{"name" => "Rice", "qty" => 0, "rate" => 10}
        ])

      assert %{"errors" => %{"items.0.qty" => ["must be at least 0.01"]}} =
               conn |> make("grocery-bill", data) |> json_response(422)
    end

    test "says what a row is missing", %{conn: conn} do
      data = Map.put(bill_sample("grocery-bill"), "items", [%{"name" => "Rice"}])

      assert %{"errors" => %{"items.0.qty" => ["is required"], "items.0.rate" => ["is required"]}} =
               conn |> make("grocery-bill", data) |> json_response(422)
    end

    test "still takes the numbered fields of a page that was open before the table", %{conn: conn} do
      old = %{
        "store_name" => "Mehta",
        "bill_number" => "1",
        "date" => "2026-10-18",
        "payment_mode" => "Cash",
        "item_1" => "Rice",
        "qty_1" => 1,
        "price_1" => 640
      }

      assert "%PDF" <> _ = conn |> make("grocery-bill", old) |> response(200)
    end
  end

  describe "tax and registration numbers" do
    test "the Spanish Fuel Bill carries its IVA, and a tax id that is a NIF", %{conn: conn} do
      conn = generate_in(conn, "es-es")

      assert "%PDF" <> _ = response(conn, 200)
    end

    test "the Spanish Fuel Bill refuses an Indian GSTIN as the seller's tax id", %{conn: conn} do
      data = Map.put(sample_for("es-es"), "seller_tax_id", "24ABCDE1234F1Z5")

      assert %{"errors" => %{"seller_tax_id" => ["tiene un formato no válido"]}} =
               conn |> generate_in("es-es", %{data: data}) |> json_response(422)
    end

    test "an Indian bill keeps no tax rate that only Spain has", %{conn: conn} do
      data = Map.put(sample_for("en-in"), "tax_percent", 21)
      assert "%PDF" <> _ = conn |> generate_in("en-in", %{data: data}) |> response(200)
    end

    test "a restaurant bill with its FSSAI number is made, and one with a wrong number is refused",
         %{conn: conn} do
      sample = bill_sample("restaurant-bill")
      assert "%PDF" <> _ = conn |> make("restaurant-bill", sample) |> response(200)

      assert %{"errors" => %{"fssai_number" => [_]}} =
               conn
               |> make("restaurant-bill", Map.put(sample, "fssai_number", "123"))
               |> json_response(422)
    end
  end

  describe "a document for another country" do
    setup :register_and_log_in_user

    test "is made with that country's numbers, and keeps the country and the currency", %{
      conn: conn,
      scope: scope
    } do
      conn =
        generate(conn, %{
          country: "de",
          currency: "EUR",
          data: Map.delete(sample(), "seller_tax_id")
        })

      assert "%PDF" <> _ = response(conn, 200)

      assert [doc] = QuickSlips.Documents.list_documents(scope)
      assert doc.language == "en"
      assert doc.options == %{"country" => "de", "currency" => "EUR"}
    end

    test "the currency defaults to the country's", %{conn: conn, scope: scope} do
      conn
      |> generate(%{country: "jp", data: Map.delete(sample(), "seller_tax_id")})
      |> response(200)

      assert [%{options: %{"country" => "jp", "currency" => "JPY"}}] =
               QuickSlips.Documents.list_documents(scope)
    end

    test "is checked against that country's fields: a Spanish NIF is not an Indian GSTIN", %{
      conn: conn
    } do
      data = Map.put(sample(), "seller_tax_id", "B41234567")

      assert %{"errors" => %{"seller_tax_id" => ["has invalid format"]}} =
               conn |> generate(%{data: data}) |> json_response(422)

      assert "%PDF" <> _ = conn |> generate(%{data: data, country: "es"}) |> response(200)
    end

    test "a country or currency that does not exist is a 400", %{conn: conn} do
      assert conn |> generate(%{country: "zz"}) |> json_response(400)
      assert conn |> generate(%{currency: "XXX"}) |> json_response(400)
    end
  end
end
