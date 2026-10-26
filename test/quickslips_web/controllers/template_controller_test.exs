defmodule QuickSlipsWeb.TemplateControllerTest do
  use QuickSlipsWeb.ConnCase

  test "shows a template", %{conn: conn} do
    conn = get(conn, ~p"/fuel-bill")
    assert html_response(conn, 200) =~ "Fuel Bill Generator"
  end

  test "unknown slug is a 404", %{conn: conn} do
    assert_error_sent 404, fn -> get(conn, ~p"/no-such-bill") end
  end
end
