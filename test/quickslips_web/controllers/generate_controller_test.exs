defmodule QuickSlipsWeb.GenerateControllerTest do
  use QuickSlipsWeb.ConnCase

  @moduletag :typst

  defp sample, do: "priv/bill_templates/fuel-bill/sample.json" |> File.read!() |> Jason.decode!()

  test "returns a PDF download", %{conn: conn} do
    conn = post(conn, ~p"/api/generate", %{slug: "fuel-bill", template: "t1", data: sample()})

    assert "%PDF" <> _ = response(conn, 200)
    assert [content_type] = get_resp_header(conn, "content-type")
    assert content_type =~ "application/pdf"
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
