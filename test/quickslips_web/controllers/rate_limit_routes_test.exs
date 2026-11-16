defmodule QuickSlipsWeb.RateLimitRoutesTest do
  # Not async: the tests set the rules, which belong to the whole application.
  use QuickSlipsWeb.ConnCase, async: false

  import QuickSlips.RateLimitHelpers

  defp from_new_address(conn), do: %{conn | remote_ip: unique_ip()}

  describe "POST /api/generate" do
    test "answers 429 `slow_down` once an address asks too often, before it looks at anything", %{
      conn: conn
    } do
      put_limit(:generate, 2, 60)
      conn = from_new_address(conn)

      # The body is no bill: the first two are refused for that (400), the third is refused for the pace (429).
      assert post(conn, ~p"/api/generate", %{}).status == 400
      assert post(conn, ~p"/api/generate", %{}).status == 400

      limited = post(conn, ~p"/api/generate", %{})
      assert %{"code" => "slow_down"} = json_response(limited, 429)
      assert [_seconds] = get_resp_header(limited, "retry-after")
    end

    test "is not the answer of the daily limit, which has no code", %{conn: conn} do
      # The page tells them apart by the code: "slow_down" is "try again", not "you have used today's downloads".
      put_limit(:generate, 1, 60)
      conn = from_new_address(conn)

      post(conn, ~p"/api/generate", %{})
      assert %{"error" => error} = json_response(post(conn, ~p"/api/generate", %{}), 429)
      refute error =~ "daily"
    end
  end

  describe "the rest of /api" do
    test "has its own, wider limit, counted before the session is read", %{conn: conn} do
      put_limit(:api, 2, 60)
      conn = from_new_address(conn)

      assert get(conn, ~p"/api/quota").status == 200
      assert get(conn, ~p"/api/quota").status == 200

      limited = get(conn, ~p"/api/quota")
      assert %{"code" => "slow_down"} = json_response(limited, 429)
      # No cookie was set: the session and the visitor were never reached.
      assert get_resp_header(limited, "set-cookie") == []
    end

    test "counts every call of /api together, whichever route", %{conn: conn} do
      put_limit(:api, 2, 60)
      conn = from_new_address(conn)

      get(conn, ~p"/api/quota")
      get(conn, ~p"/api/bill/fuel-bill/view")

      assert json_response(get(conn, ~p"/api/quota"), 429)
    end

    test "does not touch the pages of the site", %{conn: conn} do
      put_limit(:api, 1, 60)
      conn = from_new_address(conn)

      get(conn, ~p"/api/quota")
      assert get(conn, ~p"/api/quota").status == 429

      assert get(conn, ~p"/en-in").status == 200
    end
  end
end
