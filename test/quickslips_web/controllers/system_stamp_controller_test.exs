defmodule QuickSlipsWeb.SystemStampControllerTest do
  use QuickSlipsWeb.ConnCase

  # The stamps the site provides are files of priv/images/stamps, which is not under priv/static.

  test "serves a stamp of the site, to anybody, for a day", %{conn: conn} do
    conn = get(conn, "/images/stamps/india-rupee-one-revenue-stamp.jpeg")

    assert response(conn, 200) ==
             File.read!("priv/images/stamps/india-rupee-one-revenue-stamp.jpeg")

    assert ["image/jpeg" <> _] = get_resp_header(conn, "content-type")
    assert get_resp_header(conn, "cache-control") == ["public, max-age=86400"]
    assert get_resp_header(conn, "set-cookie") == []
  end

  test "serves nothing else: only a file that is in the list", %{conn: conn} do
    for file <- ["nothing.png", "mix.exs", "india-rupee-one-revenue-stamp"] do
      assert conn |> get("/images/stamps/#{file}") |> response(404)
    end
  end
end
