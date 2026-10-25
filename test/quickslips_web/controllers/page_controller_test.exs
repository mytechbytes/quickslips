defmodule QuickSlipsWeb.PageControllerTest do
  use QuickSlipsWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "QuickSlips"
  end
end
