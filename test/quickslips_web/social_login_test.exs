defmodule QuickSlipsWeb.SocialLoginTest do
  # `enabled?/1` reads keys that belong to the whole application, so these tests run one at a time.
  use ExUnit.Case, async: false

  import QuickSlips.SiteHelpers

  alias QuickSlipsWeb.SocialLogin

  describe "enabled?/1" do
    test "Google is always offered" do
      assert SocialLogin.enabled?(:google)
    end

    test "Microsoft is offered when both of its keys are set (the tests have them)" do
      assert SocialLogin.enabled?(:microsoft)
    end

    test "Microsoft is not offered without its keys, or with only one of them, or with empty ones" do
      for keys <- [
            [],
            [client_id: nil, client_secret: nil],
            [client_id: "an-id"],
            [client_secret: "a-secret"],
            [client_id: "an-id", client_secret: ""],
            [client_id: "  ", client_secret: "a-secret"]
          ] do
        put_microsoft_keys(keys)
        refute SocialLogin.enabled?(:microsoft), inspect(keys)
      end
    end
  end

  # What Ueberauth leaves in the `Auth` after the strategy of Google or Microsoft has run.
  defp auth(provider, attrs) do
    struct!(
      %Ueberauth.Auth{
        provider: provider,
        uid: "an-id",
        info: %Ueberauth.Auth.Info{},
        extra: %Ueberauth.Auth.Extra{raw_info: %{user: %{}}}
      },
      attrs
    )
  end

  defp microsoft(email, extra \\ %{}) do
    auth(:microsoft,
      uid: "ms-id",
      info: %Ueberauth.Auth.Info{name: "Maria Silva", email: email},
      extra: %Ueberauth.Auth.Extra{raw_info: %{user: extra}}
    )
  end

  describe "user_info/1 for Google" do
    test "takes the answer as it is, and trusts the address only when Google says it is verified" do
      google = fn verified ->
        auth(:google,
          uid: "g-id",
          info: %Ueberauth.Auth.Info{
            name: "Gina Person",
            email: "gina@example.com",
            image: "https://example.com/gina.png"
          },
          extra: %Ueberauth.Auth.Extra{raw_info: %{user: %{"email_verified" => verified}}}
        )
      end

      assert SocialLogin.user_info(google.(true)) == %{
               uid: "g-id",
               email: "gina@example.com",
               name: "Gina Person",
               avatar_url: "https://example.com/gina.png",
               email_verified?: true
             }

      refute SocialLogin.user_info(google.(false)).email_verified?
      refute SocialLogin.user_info(google.(nil)).email_verified?
      # only a real `true`: a string in its place is not taken for it
      refute SocialLogin.user_info(google.("true")).email_verified?
    end
  end

  describe "user_info/1 for Microsoft" do
    test "takes the id, the name and the sign-in address, and has no picture" do
      assert SocialLogin.user_info(microsoft("maria@outlook.com")) == %{
               uid: "ms-id",
               email: "maria@outlook.com",
               name: "Maria Silva",
               avatar_url: nil,
               email_verified?: true
             }
    end

    test "writes the address in lower case, as it is looked up" do
      info = SocialLogin.user_info(microsoft("Maria.Silva@Contoso.COM"))

      assert info.email == "maria.silva@contoso.com"
      assert info.email_verified?
    end

    test "never uses the \"mail\" field, which whoever runs an organisation can fill with anyone's address" do
      info =
        SocialLogin.user_info(
          microsoft("attacker@evil.onmicrosoft.com", %{"mail" => "victim@gmail.com"})
        )

      assert info.email == "attacker@evil.onmicrosoft.com"
    end

    test "turns away a guest's made-up name, which is no address anyone can write to" do
      for guest <- [
            "maria_gmail.com#EXT#@firm.onmicrosoft.com",
            "live.com#maria@gmail.com"
          ] do
        refute SocialLogin.user_info(microsoft(guest)).email_verified?, guest
      end
    end

    test "turns away what is no address: none, no @, no domain with a dot, spaces" do
      for not_an_address <- [
            nil,
            "",
            "maria",
            "maria@",
            "@outlook.com",
            "maria@localhost",
            "ma ria@outlook.com"
          ] do
        refute SocialLogin.user_info(microsoft(not_an_address)).email_verified?,
               inspect(not_an_address)
      end
    end
  end
end
