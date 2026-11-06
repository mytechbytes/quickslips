defmodule QuickSlipsWeb.TemplateSourceControllerTest do
  use QuickSlipsWeb.ConnCase

  test "serves the source of a template as plain text", %{conn: conn} do
    conn = get(conn, ~p"/source/fuel-bill/t1")

    assert response(conn, 200) =~ ~s(#import "_shared/helpers.typ")
    assert ["text/plain" <> _] = get_resp_header(conn, "content-type")
  end

  test "serves the helpers that every template imports", %{conn: conn} do
    conn = get(conn, ~p"/source/_shared/helpers")

    assert response(conn, 200) =~ "#let money(n)"
    assert ["text/plain" <> _] = get_resp_header(conn, "content-type")
  end

  test "nothing else is served", %{conn: conn} do
    assert_error_sent 404, fn -> get(conn, ~p"/source/_shared/secret") end
    assert_error_sent 404, fn -> get(conn, ~p"/source/fuel-bill/t9") end
    assert_error_sent 404, fn -> get(conn, ~p"/source/no-such-template/t1") end
  end
end
