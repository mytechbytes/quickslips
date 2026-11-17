defmodule QuickSlipsWeb.UserLive.SocialButtonsTest do
  # Whether Microsoft has its keys is a setting of the whole application, so these tests run one at a time.
  use QuickSlipsWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import QuickSlips.SiteHelpers

  # The log-in page and the sign-up page end the same way: "or", and a button for each provider that is set up.
  for path <- ["/users/log-in", "/users/register"] do
    test "#{path} offers Google and Microsoft, and the buttons look alike", %{conn: conn} do
      {:ok, view, _html} = live(conn, unquote(path))

      assert has_element?(view, ~s(a#google-login[href="/auth/google"]), "Continue with Google")

      assert has_element?(
               view,
               ~s(a#microsoft-login[href="/auth/microsoft"]),
               "Continue with Microsoft"
             )

      # one logo each, drawn by the page itself
      assert has_element?(view, ~s(#google-login img[src^="/images/google.svg"]))
      assert has_element?(view, ~s(#microsoft-login img[src^="/images/microsoft.svg"]))
    end

    test "#{path} offers only Google while Microsoft has no keys", %{conn: conn} do
      put_microsoft_keys([])

      {:ok, view, _html} = live(conn, unquote(path))

      assert has_element?(view, "#google-login")
      refute has_element?(view, "#microsoft-login")
    end
  end

  test "the logo of Microsoft is a file of the site" do
    svg = File.read!(Path.join(["priv", "static", "images", "microsoft.svg"]))

    # the four squares, in Microsoft's four colours
    for colour <- ~w(#F25022 #7FBA00 #00A4EF #FFB900) do
      assert svg =~ colour
    end
  end
end
