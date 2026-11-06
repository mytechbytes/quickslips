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
end
