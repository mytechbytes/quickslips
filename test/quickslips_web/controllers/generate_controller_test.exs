defmodule QuickSlipsWeb.GenerateControllerTest do
  use QuickSlipsWeb.ConnCase

  @moduletag :typst

  setup do
    Req.Test.stub(QuickSlips.Turnstile, fn conn -> Req.Test.json(conn, %{"success" => true}) end)
    :ok
  end

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
end
