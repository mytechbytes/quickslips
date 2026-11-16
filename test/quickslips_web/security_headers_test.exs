defmodule QuickSlipsWeb.SecurityHeadersTest do
  # Not async: some tests change the settings of the policy, which belong to the whole application.
  use QuickSlipsWeb.ConnCase, async: false

  alias QuickSlipsWeb.ContentSecurityPolicy

  # The settings put back as they were when the test ends.
  defp put_setting(key, value) do
    previous = Application.fetch_env(:quickslips, key)
    Application.put_env(:quickslips, key, value)

    on_exit(fn ->
      case previous do
        {:ok, old} -> Application.put_env(:quickslips, key, old)
        :error -> Application.delete_env(:quickslips, key)
      end
    end)
  end

  defp policy(conn), do: conn |> get_resp_header("content-security-policy") |> hd()

  defp directive(policy, name) do
    policy
    |> String.split("; ")
    |> Enum.find_value(fn part ->
      case String.split(part, " ") do
        [^name | sources] -> sources
        _other -> nil
      end
    end)
  end

  defp nonce_of(policy) do
    [nonce] = Regex.run(~r/'nonce-([^']+)'/, policy, capture: :all_but_first)
    nonce
  end

  # The scripts of a page that are written in it, not loaded: the data of JSON-LD is not run, so it does not count.
  defp inline_scripts(html) do
    html
    |> LazyHTML.from_document()
    |> LazyHTML.query("script:not([src]):not([type='application/ld+json'])")
    |> Enum.to_list()
  end

  describe "the policy of a page" do
    test "lists where each kind of thing may come from, and nothing is open to every script", %{
      conn: conn
    } do
      policy = conn |> get(~p"/en-in") |> policy()

      assert directive(policy, "default-src") == ["'self'"]
      assert directive(policy, "object-src") == ["'none'"]
      assert directive(policy, "base-uri") == ["'self'"]
      assert directive(policy, "form-action") == ["'self'"]
      assert directive(policy, "frame-ancestors") == ["'self'"]

      scripts = directive(policy, "script-src")
      assert "'self'" in scripts
      assert "https://challenges.cloudflare.com" in scripts
      assert "https://www.googletagmanager.com" in scripts
      # The preview starts WebAssembly; that does not make text into code
      assert "'wasm-unsafe-eval'" in scripts
      refute "'unsafe-inline'" in scripts
      refute "'unsafe-eval'" in scripts
      refute "*" in scripts
      refute Enum.any?(scripts, &(&1 in ["data:", "http:", "https:"]))
    end

    test "has the one policy, and not the short one that put_secure_browser_headers makes", %{
      conn: conn
    } do
      conn = get(conn, ~p"/en-in")

      assert [_one] = get_resp_header(conn, "content-security-policy")
      assert get_resp_header(conn, "content-security-policy-report-only") == []
    end

    test "has a nonce, which is the one of the script of the layout and of no other", %{
      conn: conn
    } do
      conn = get(conn, ~p"/en-in")
      nonce = conn |> policy() |> nonce_of()

      assert [script] = conn |> html_response(200) |> inline_scripts()
      assert LazyHTML.attribute(script, "nonce") == [nonce]
      # 128 bits
      assert byte_size(Base.decode64!(nonce)) == 16
    end

    test "has a new nonce for each response", %{conn: conn} do
      one = conn |> get(~p"/en-in") |> policy() |> nonce_of()
      other = build_conn() |> get(~p"/en-in") |> policy() |> nonce_of()

      refute one == other
    end

    test "covers every page of the :browser pipeline, with a script that has the nonce: log-in, sign-up, a bill",
         %{
           conn: conn
         } do
      for path <- [
            ~p"/users/log-in",
            ~p"/users/register",
            ~p"/en-in/fuel-bill-generator",
            ~p"/contact"
          ] do
        conn = get(build_conn(), path)
        nonce = conn |> policy() |> nonce_of()

        assert [script] = conn |> html_response(200) |> inline_scripts(), path
        assert LazyHTML.attribute(script, "nonce") == [nonce], path
      end

      _ = conn
    end

    test "lets the connection of the LiveView socket go to the site, in full as well as with 'self'",
         %{
           conn: conn
         } do
      connect = conn |> get(~p"/en-in") |> policy() |> directive("connect-src")

      assert "'self'" in connect
      # The endpoint of the tests is on http://localhost
      assert Enum.any?(connect, &String.starts_with?(&1, "ws://localhost"))
      assert "https://challenges.cloudflare.com" in connect
      assert "https://*.google-analytics.com" in connect
    end

    test "lets the pictures of the preview and of the icons be shown", %{conn: conn} do
      images = conn |> get(~p"/en-in") |> policy() |> directive("img-src")

      assert "blob:" in images
      assert "data:" in images
    end

    test "lets the widget of Turnstile be framed", %{conn: conn} do
      frames = conn |> get(~p"/en-in") |> policy() |> directive("frame-src")

      assert "https://challenges.cloudflare.com" in frames
    end
  end

  describe "what is done with the policy" do
    test "it can only report, in the development machine and while a change is tried", %{
      conn: conn
    } do
      put_setting(:csp, :report_only)

      conn = get(conn, ~p"/en-in")

      # What Phoenix puts on every page stays enforced; ours is only reported
      assert [short] = get_resp_header(conn, "content-security-policy")
      refute short =~ "script-src"
      assert [report] = get_resp_header(conn, "content-security-policy-report-only")
      assert report =~ "default-src 'self'"
      # The page is still given its nonce: nothing in it changes with the mode
      assert [_script] = conn |> html_response(200) |> inline_scripts()
    end

    test "it can be off, and the page works all the same", %{conn: conn} do
      put_setting(:csp, :off)

      conn = get(conn, ~p"/en-in")

      # Nothing of ours: only what Phoenix puts on every page
      for header <- get_resp_header(conn, "content-security-policy") do
        refute header =~ "script-src"
      end

      assert get_resp_header(conn, "content-security-policy-report-only") == []
      assert html_response(conn, 200) =~ "QuickSlips"
    end

    test "it asks the browser to make every address https where the site is on https" do
      policy = ContentSecurityPolicy.build("abc", "https://quickslips.example")

      assert directive(policy, "upgrade-insecure-requests") == []
      assert "wss://quickslips.example" in directive(policy, "connect-src")
      refute policy =~ "ws://quickslips.example"
    end

    test "it names the port of a site that is not on the usual one, and does not upgrade http" do
      policy = ContentSecurityPolicy.build("abc", "http://localhost:4000")

      assert "ws://localhost:4000" in directive(policy, "connect-src")
      refute policy =~ "upgrade-insecure-requests"
    end
  end

  describe "the headers of every response" do
    test "are on a page", %{conn: conn} do
      conn = get(conn, ~p"/en-in")

      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
      assert get_resp_header(conn, "x-frame-options") == ["SAMEORIGIN"]
      assert get_resp_header(conn, "referrer-policy") == ["strict-origin-when-cross-origin"]
      assert get_resp_header(conn, "cross-origin-opener-policy") == ["same-origin"]
      assert [permissions] = get_resp_header(conn, "permissions-policy")

      for feature <- ~w(camera microphone geolocation usb) do
        assert permissions =~ "#{feature}=()"
      end
    end

    test "are on the JSON of the API, which has no policy of its own to give", %{conn: conn} do
      conn = get(conn, ~p"/api/quota")

      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
      assert get_resp_header(conn, "cross-origin-opener-policy") == ["same-origin"]
      assert get_resp_header(conn, "permissions-policy") != []
      assert get_resp_header(conn, "content-security-policy") == []
    end

    test "are on a file of priv/static, which the router never sees", %{conn: conn} do
      conn = get(conn, "/favicon.ico")

      assert conn.status == 200
      assert get_resp_header(conn, "x-content-type-options") == ["nosniff"]
      assert get_resp_header(conn, "permissions-policy") != []
      assert get_resp_header(conn, "cross-origin-opener-policy") == ["same-origin"]
    end

    test "are on the robots file and the sitemap, which have no pipeline", %{conn: conn} do
      for path <- [~p"/robots.txt", ~p"/sitemap.xml"] do
        conn = get(build_conn(), path)
        assert get_resp_header(conn, "x-content-type-options") == ["nosniff"], path
      end

      _ = conn
    end

    test "leave out the opener policy when it is turned off", %{conn: conn} do
      put_setting(:cross_origin_opener_policy, nil)

      assert get_resp_header(get(conn, ~p"/en-in"), "cross-origin-opener-policy") == []
    end

    test "take the opener policy from the setting", %{conn: conn} do
      put_setting(:cross_origin_opener_policy, "unsafe-none")

      assert get_resp_header(get(conn, ~p"/en-in"), "cross-origin-opener-policy") == [
               "unsafe-none"
             ]
    end
  end

  describe "the error dashboard, which has its script and its styles in the page" do
    setup :register_and_log_in_user

    test "gets the nonce of the policy, or the browser would not run it", %{
      conn: conn,
      user: user
    } do
      put_setting(:admin_emails, [String.downcase(user.email)])

      conn = get(conn, ~p"/admin/errors")
      nonce = conn |> policy() |> nonce_of()
      html = html_response(conn, 200)

      assert [script] = inline_scripts(html)
      assert LazyHTML.attribute(script, "nonce") == [nonce]
    end
  end
end
