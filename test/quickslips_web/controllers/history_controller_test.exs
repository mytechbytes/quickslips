defmodule QuickSlipsWeb.HistoryControllerTest do
  use QuickSlipsWeb.ConnCase

  import QuickSlips.AccountsFixtures
  import QuickSlips.BusinessesFixtures
  import QuickSlips.DocumentsFixtures
  import QuickSlips.UploadsFixtures

  @moduletag :typst

  defp sample(slug),
    do: "priv/bill_templates/#{slug}/sample.json" |> File.read!() |> Jason.decode!()

  test "visitors are sent to the log-in page", %{conn: conn} do
    conn = get(conn, ~p"/history/1/download")
    assert redirected_to(conn) == ~p"/users/log-in"
  end

  describe "when logged in" do
    setup :register_and_log_in_user

    test "makes the PDF again from the saved data", %{conn: conn, scope: scope} do
      doc = document_fixture(scope, %{data: sample("fuel-bill")})

      conn = get(conn, ~p"/history/#{doc.id}/download")

      assert "%PDF" <> _ = response(conn, 200)
      assert ["application/pdf" <> _] = get_resp_header(conn, "content-type")
      assert [disposition] = get_resp_header(conn, "content-disposition")
      assert disposition =~ ~s(filename="fuel-bill.pdf")
    end

    test "makes it in the language and for the country it was made for", %{
      conn: conn,
      scope: scope
    } do
      for {language, country, currency, code} <- [
            {"hi", "in", "INR", "hi-in"},
            {"es", "es", "EUR", "es-es"}
          ] do
        {:ok, sample} = QuickSlips.Templates.sample("fuel-bill", QuickSlips.Locales.fetch!(code))

        doc =
          document_fixture(scope, %{
            data: sample,
            language: language,
            options: %{"country" => country, "currency" => currency}
          })

        conn = get(conn, ~p"/history/#{doc.id}/download")

        assert "%PDF" <> _ = response(conn, 200)
      end
    end

    test "goes back to the list when the template is not in the language of the document", %{
      conn: conn,
      scope: scope
    } do
      doc =
        document_fixture(scope, %{
          slug: "grocery-bill",
          data: sample("grocery-bill"),
          language: "hi",
          options: %{"country" => "in"}
        })

      conn = get(conn, ~p"/history/#{doc.id}/download")

      assert redirected_to(conn) == ~p"/history"
    end

    test "does not use up a download of the day", %{conn: conn, user: user, scope: scope} do
      doc = document_fixture(scope, %{data: sample("fuel-bill")})
      before = QuickSlips.Downloads.status(%{user: user})

      conn |> get(~p"/history/#{doc.id}/download") |> response(200)

      assert QuickSlips.Downloads.status(%{user: user}) == before
    end

    test "draws the pictures of the business the document was made with", %{
      conn: conn,
      user: user,
      scope: scope
    } do
      business = business_fixture(scope, %{}, %{logo_path: stored_image(user.id)})
      plain = document_fixture(scope, %{data: sample("fuel-bill")})
      branded = document_fixture(scope, %{data: sample("fuel-bill")}, business)

      plain_pdf = conn |> get(~p"/history/#{plain.id}/download") |> response(200)
      branded_pdf = conn |> get(~p"/history/#{branded.id}/download") |> response(200)

      assert byte_size(branded_pdf) > byte_size(plain_pdf)
    end

    test "is a 404 for somebody else's document", %{conn: conn} do
      doc = document_fixture(user_scope_fixture(), %{data: sample("fuel-bill")})

      assert_error_sent 404, fn -> get(conn, ~p"/history/#{doc.id}/download") end
    end

    test "goes back to the list when the template is gone", %{conn: conn, scope: scope} do
      doc = document_fixture(scope, %{slug: "no-such-template", data: sample("fuel-bill")})

      conn = get(conn, ~p"/history/#{doc.id}/download")

      assert redirected_to(conn) == ~p"/history"
      assert Phoenix.Flash.get(conn.assigns.flash, :error) =~ "Edit and regenerate"
    end

    test "goes back to the list when the saved data no longer fits the template", %{
      conn: conn,
      scope: scope
    } do
      doc = document_fixture(scope, %{data: %{"station_name" => "Only a name"}})

      conn = get(conn, ~p"/history/#{doc.id}/download")

      assert redirected_to(conn) == ~p"/history"
    end
  end

  describe "a document made before the table of items" do
    setup :register_and_log_in_user

    test "is made again from its numbered fields", %{conn: conn, scope: scope} do
      old = %{
        "store_name" => "Mehta",
        "bill_number" => "1",
        "date" => "2026-10-18",
        "payment_mode" => "Cash",
        "item_1" => "Rice",
        "qty_1" => 1,
        "price_1" => 640,
        "item_2" => "Dal",
        "qty_2" => 2,
        "price_2" => 165
      }

      doc = document_fixture(scope, %{slug: "grocery-bill", data: old})

      assert "%PDF" <> _ = conn |> get(~p"/history/#{doc.id}/download") |> response(200)
    end

    test "opens in the form with its rows", %{conn: conn, scope: scope} do
      old = %{
        "store_name" => "Mehta",
        "bill_number" => "1",
        "date" => "2026-10-18",
        "payment_mode" => "Cash",
        "item_1" => "Rice",
        "qty_1" => 1,
        "price_1" => 640
      }

      doc = document_fixture(scope, %{slug: "grocery-bill", data: old})

      html = conn |> get("/en-in/grocery-bill-generator?from=#{doc.id}") |> html_response(200)

      assert html =~ "&quot;items&quot;:[{&quot;name&quot;:&quot;Rice&quot;"
      refute html =~ "item_1"
    end
  end

  describe "a document made for another country" do
    setup :register_and_log_in_user

    test "is made again for that country", %{conn: conn, scope: scope} do
      doc =
        document_fixture(scope, %{
          data: Map.put(sample("fuel-bill"), "seller_tax_id", "B41234567"),
          options: %{"country" => "es", "currency" => "EUR"}
        })

      # as an English document for Spain it has a Spanish NIF, which an Indian one would refuse
      assert "%PDF" <> _ = conn |> get(~p"/history/#{doc.id}/download") |> response(200)
    end
  end
end
