defmodule QuickSlipsWeb.RobotsControllerTest do
  use QuickSlipsWeb.ConnCase

  alias QuickSlipsWeb.Endpoint

  setup %{conn: conn} do
    conn = get(conn, ~p"/robots.txt")

    %{
      conn: conn,
      body: response(conn, 200),
      lines: conn |> response(200) |> String.split("\n", trim: true)
    }
  end

  test "is plain text that a crawler may keep for an hour", %{conn: conn} do
    assert ["text/plain" <> _] = get_resp_header(conn, "content-type")
    assert get_resp_header(conn, "cache-control") == ["public, max-age=3600"]
  end

  test "sets no cookie", %{conn: conn} do
    assert get_resp_header(conn, "set-cookie") == []
  end

  test "lets every crawler in, and says where the sitemap is, with the whole address", %{
    lines: lines
  } do
    assert "User-agent: *" in lines
    assert "Allow: /" in lines
    assert "Sitemap: #{Endpoint.url()}/sitemap.xml" in lines
  end

  test "keeps out what is not for a search engine", %{lines: lines} do
    for path <-
          ~w(/api/ /uploads/ /source/ /users/ /auth/ /dashboard /businesses /signatures /history /admin/) do
      assert "Disallow: #{path}" in lines, path
    end
  end

  test "leaves the scripts and the styles alone, since a crawler that draws a page needs them", %{
    body: body
  } do
    for path <- ~w(/assets /fonts /wasm /images) do
      refute body =~ "Disallow: #{path}", path
    end
  end

  test "no page of the site is kept out", %{lines: lines} do
    for locale <- QuickSlips.Locales.live() do
      refute Enum.any?(lines, &(&1 == "Disallow: /#{locale.code}"))
    end

    refute "Disallow: /" in lines
  end

  test "the file is not a static one: the address of the sitemap comes from the configuration" do
    refute File.exists?("priv/static/robots.txt")
    refute "robots.txt" in QuickSlipsWeb.static_paths()
  end
end
