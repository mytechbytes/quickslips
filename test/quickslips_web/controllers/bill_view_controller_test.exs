defmodule QuickSlipsWeb.BillViewControllerTest do
  use QuickSlipsWeb.ConnCase

  defp view(conn, slug, query),
    do: get(conn, "/api/bill/#{slug}/view?" <> URI.encode_query(query))

  defp field(body, key), do: Enum.find(body["fields"], &(&1["key"] == key))

  test "gives the form of a bill for another country than its page", %{conn: conn} do
    body = conn |> view("fuel-bill", locale: "hi-in", country: "es") |> json_response(200)

    assert body["tax_mode"] == "included"
    assert field(body, "tax_percent")["rates"] == [0, 4, 10, 21]
    assert field(body, "seller_tax_id")["pattern"] =~ "XYZ"
    # the words stay the language of the page
    assert field(body, "station_name")["label"] == "पेट्रोल पंप का नाम"
    assert body["region"]["country"] == "es"
    assert body["region"]["currency"]["code"] == "EUR"
    assert body["text"]["lang"] == "hi"
  end

  test "a currency of its own, and a country that takes it from the locale", %{conn: conn} do
    body = conn |> view("restaurant-bill", country: "jp", currency: "USD") |> json_response(200)
    assert body["region"]["currency"]["code"] == "USD"
    assert body["region"]["date"]["order"] == "ymd"
    assert field(body, "gst_percent")["rates"] == [0, 8, 10]
    assert field(body, "fssai_number") == nil

    body = conn |> view("restaurant-bill", locale: "en-in") |> json_response(200)
    assert body["region"]["country"] == "in"
    assert field(body, "fssai_number")["pattern"] == "^[0-9]{14}$"
  end

  test "refuses what does not exist", %{conn: conn} do
    assert conn |> view("fuel-bill", country: "zz") |> json_response(400)
    assert conn |> view("fuel-bill", currency: "XXX") |> json_response(400)
    assert conn |> view("fuel-bill", locale: "es-mx") |> json_response(400)
    assert conn |> view("nope", country: "es") |> json_response(404)
    # a template that is not in the language of the page
    assert conn |> view("courier-receipt", locale: "hi-in") |> json_response(404)
  end
end
