defmodule QuickSlipsWeb.AuthControllerTest do
  # Whether Microsoft has its keys is a setting of the whole application, so these tests run one at a time.
  use QuickSlipsWeb.ConnCase, async: false

  import QuickSlips.AccountsFixtures
  import QuickSlips.SiteHelpers

  alias QuickSlips.Accounts.User
  alias QuickSlips.Repo
  alias QuickSlipsWeb.AuthController

  describe "GET /auth/microsoft" do
    test "sends the visitor to Microsoft, asking for no more than it needs", %{conn: conn} do
      conn = get(conn, ~p"/auth/microsoft")

      uri = conn |> redirected_to(302) |> URI.parse()
      query = URI.decode_query(uri.query)

      # `common` takes personal accounts as well as work and school ones; the app's registration says which are allowed
      assert uri.host == "login.microsoftonline.com"
      assert uri.path == "/common/oauth2/v2.0/authorize"
      assert query["client_id"] == "test-microsoft-client-id"
      assert query["response_type"] == "code"
      assert query["redirect_uri"] =~ "/auth/microsoft/callback"
      # no "offline_access": no refresh token is asked for, because none is kept
      assert query["scope"] == "https://graph.microsoft.com/user.read openid"
      assert query["state"] != ""
      # the state is checked when Microsoft sends the visitor back, against this cookie
      assert conn.resp_cookies["ueberauth.state_param"]
    end

    test "is not there while the keys are not set, so nobody lands on an error page of Microsoft's",
         %{conn: conn} do
      put_microsoft_keys([])

      assert text_response(get(conn, ~p"/auth/microsoft"), 404) == "Unknown login provider"

      assert text_response(get(conn, ~p"/auth/microsoft/callback"), 404) ==
               "Unknown login provider"
    end

    test "is not there with only one of the two keys", %{conn: conn} do
      put_microsoft_keys(client_id: "an-id")

      assert text_response(get(conn, ~p"/auth/microsoft"), 404) == "Unknown login provider"
    end
  end

  describe "GET /auth/:provider" do
    test "an unknown provider is a 404", %{conn: conn} do
      assert text_response(get(conn, "/auth/twitter"), 404) == "Unknown login provider"
      assert text_response(get(conn, "/auth/twitter/callback"), 404) == "Unknown login provider"
    end

    test "Google is not affected by the keys of Microsoft", %{conn: conn} do
      put_microsoft_keys([])

      assert redirected_to(get(conn, ~p"/auth/google"), 302) =~ "accounts.google.com"
    end
  end

  # The answer of Ueberauth, as the controller finds it when its action starts. The step before (the visitor and the
  # provider talking to each other) needs the provider, so it is not run here.
  defp callback(conn, provider, assigns) do
    conn
    |> bypass_through(QuickSlipsWeb.Router, [:browser])
    |> get("/auth/#{provider}/callback")
    |> merge_assigns(assigns)
    |> AuthController.callback(%{})
  end

  defp microsoft_auth(email, attrs \\ []) do
    struct!(
      %Ueberauth.Auth{
        provider: :microsoft,
        strategy: Ueberauth.Strategy.Microsoft,
        uid: "ms-#{System.unique_integer([:positive])}",
        info: %Ueberauth.Auth.Info{name: "Maria Silva", email: email},
        extra: %Ueberauth.Auth.Extra{raw_info: %{user: %{}}}
      },
      attrs
    )
  end

  defp google_auth(email, verified) do
    %Ueberauth.Auth{
      provider: :google,
      strategy: Ueberauth.Strategy.Google,
      uid: "g-#{System.unique_integer([:positive])}",
      info: %Ueberauth.Auth.Info{name: "Gina Person", email: email},
      extra: %Ueberauth.Auth.Extra{raw_info: %{user: %{"email_verified" => verified}}}
    }
  end

  defp flash(conn, kind), do: Phoenix.Flash.get(conn.assigns.flash, kind)

  describe "the callback of Microsoft" do
    test "signs a new person in and creates their account", %{conn: conn} do
      auth = microsoft_auth("Maria.Silva@Outlook.com")

      conn = callback(conn, "microsoft", ueberauth_auth: auth)

      assert redirected_to(conn) == "/"
      assert get_session(conn, :user_token)
      assert flash(conn, :info) == "Welcome!"

      user = Repo.get_by!(User, microsoft_uid: auth.uid)
      assert user.email == "maria.silva@outlook.com"
      assert user.name == "Maria Silva"
      assert user.confirmed_at
      assert is_nil(user.hashed_password)
      assert is_nil(user.google_uid)
    end

    test "signs in the person whose account has the same address, and does not make another", %{
      conn: conn
    } do
      existing = user_fixture()
      auth = microsoft_auth(existing.email)

      conn = callback(conn, "microsoft", ueberauth_auth: auth)

      assert get_session(conn, :user_token)
      assert Repo.aggregate(User, :count) == 1
      assert Repo.get!(User, existing.id).microsoft_uid == auth.uid
    end

    test "turns away an account with no address that can be used, and signs nobody in", %{
      conn: conn
    } do
      guest = microsoft_auth("maria_gmail.com#EXT#@firm.onmicrosoft.com")

      conn = callback(conn, "microsoft", ueberauth_auth: guest)

      assert redirected_to(conn) == "/users/log-in"
      refute get_session(conn, :user_token)

      assert flash(conn, :error) ==
               "We couldn't get a verified email address from your Microsoft account."

      assert Repo.aggregate(User, :count) == 0
    end

    test "says so when Microsoft's answer is a failure (the visitor said no, or it did not go through)",
         %{conn: conn} do
      failure = %Ueberauth.Failure{
        provider: :microsoft,
        strategy: Ueberauth.Strategy.Microsoft,
        errors: [
          %Ueberauth.Failure.Error{message_key: "access_denied", message: "The visitor said no"}
        ]
      }

      conn = callback(conn, "microsoft", ueberauth_failure: failure)

      assert redirected_to(conn) == "/users/log-in"
      refute get_session(conn, :user_token)
      assert flash(conn, :error) == "Microsoft sign-in didn't complete. Please try again."
    end
  end

  describe "the callback of Google, which is as it was" do
    test "signs a new person in", %{conn: conn} do
      auth = google_auth("gina@example.com", true)

      conn = callback(conn, "google", ueberauth_auth: auth)

      assert redirected_to(conn) == "/"
      assert get_session(conn, :user_token)
      assert Repo.get_by!(User, google_uid: auth.uid).email == "gina@example.com"
    end

    test "turns away an address that Google does not say is verified", %{conn: conn} do
      conn = callback(conn, "google", ueberauth_auth: google_auth("gina@example.com", false))

      assert redirected_to(conn) == "/users/log-in"
      assert flash(conn, :error) == "Google says that email address isn't verified."
      assert Repo.aggregate(User, :count) == 0
    end

    test "says so when Google's answer is a failure", %{conn: conn} do
      failure = %Ueberauth.Failure{
        provider: :google,
        strategy: Ueberauth.Strategy.Google,
        errors: []
      }

      conn = callback(conn, "google", ueberauth_failure: failure)

      assert redirected_to(conn) == "/users/log-in"
      assert flash(conn, :error) == "Google sign-in didn't complete. Please try again."
    end
  end
end
