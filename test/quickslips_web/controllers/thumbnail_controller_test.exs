defmodule QuickSlipsWeb.ThumbnailControllerTest do
  use QuickSlipsWeb.ConnCase

  @moduletag :typst

  # The small picture of a design, for the picker on a bill's page.

  test "draws a design of a bill as a PNG, for anybody, and lets it be kept for a day", %{
    conn: conn
  } do
    conn = get(conn, "/thumbnails/fuel-bill/t1")

    assert <<0x89, "PNG", _::binary>> = response(conn, 200)
    assert ["image/png" <> _] = get_resp_header(conn, "content-type")
    assert get_resp_header(conn, "cache-control") == ["public, max-age=86400"]
    assert get_resp_header(conn, "set-cookie") == []
  end

  test "gives the same picture the second time, from the folder where it was kept", %{conn: conn} do
    pattern = Path.join(System.tmp_dir!(), "quickslips-thumbnails/rent-receipt-t2-*.png")
    # pictures kept for an older version of the design are not what this test is about
    Enum.each(Path.wildcard(pattern), &File.rm/1)

    first = conn |> get("/thumbnails/rent-receipt/t2") |> response(200)
    second = conn |> get("/thumbnails/rent-receipt/t2") |> response(200)

    assert first == second

    assert [_one] = Path.wildcard(pattern)
  end

  test "is a picture of each design, so two designs differ", %{conn: conn} do
    one = conn |> get("/thumbnails/fuel-bill/t1") |> response(200)
    two = conn |> get("/thumbnails/fuel-bill/t2") |> response(200)

    assert one != two
  end

  test "is a 404 for a bill or a design that does not exist, and for anything else", %{conn: conn} do
    for path <- [
          "/thumbnails/nope/t1",
          "/thumbnails/fuel-bill/t99",
          "/thumbnails/fuel-bill/main",
          "/thumbnails/_shared/helpers"
        ] do
      assert conn |> get(path) |> response(404), path
    end
  end
end
