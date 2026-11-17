defmodule QuickSlips.AccountsSocialTest do
  use QuickSlips.DataCase

  alias QuickSlips.Accounts
  alias QuickSlips.Accounts.User
  alias QuickSlips.Repo

  import QuickSlips.AccountsFixtures

  # What `QuickSlipsWeb.SocialLogin.user_info/1` builds from the answer of Google or Microsoft.
  defp info(attrs \\ %{}) do
    Map.merge(
      %{
        uid: "uid-#{System.unique_integer([:positive])}",
        email: unique_user_email(),
        name: "Gina Person",
        avatar_url: "https://example.com/gina.png",
        email_verified?: true
      },
      attrs
    )
  end

  # The two providers work the same way: each has its own column for the id it gives to the person.
  for provider <- [:google, :microsoft] do
    describe "get_or_register_social_user/2 with #{provider}" do
      test "case 1: a new user is created, confirmed, with no password" do
        provider = unquote(provider)
        info = info()

        assert {:ok, user} = Accounts.get_or_register_social_user(provider, info)
        assert user.confirmed_at
        assert user.email == info.email
        assert user.name == "Gina Person"
        assert Map.fetch!(user, User.social_uid_field(provider)) == info.uid
        assert is_nil(user.hashed_password)
      end

      test "case 2: an existing password user with the same email is linked, not duplicated" do
        provider = unquote(provider)
        existing = user_fixture()
        info = info(%{email: existing.email})

        assert {:ok, user} = Accounts.get_or_register_social_user(provider, info)
        assert user.id == existing.id
        assert Map.fetch!(user, User.social_uid_field(provider)) == info.uid
        assert Repo.aggregate(User, :count) == 1
        # their password still works
        assert Accounts.get_user_by_email_and_password(existing.email, valid_user_password())
      end

      test "case 3: a user who came in this way can set a password later" do
        {:ok, user} = Accounts.get_or_register_social_user(unquote(provider), info())

        {:ok, {user, _expired}} =
          Accounts.update_user_password(user, %{
            password: "P@ssword",
            password_confirmation: "P@ssword"
          })

        assert Accounts.get_user_by_email_and_password(user.email, "P@ssword")
      end

      test "a second sign-in finds the same user by the id, even if the address has changed" do
        provider = unquote(provider)
        info = info()
        {:ok, first} = Accounts.get_or_register_social_user(provider, info)

        assert {:ok, second} =
                 Accounts.get_or_register_social_user(
                   provider,
                   %{info | email: unique_user_email()}
                 )

        assert first.id == second.id
        assert Repo.aggregate(User, :count) == 1
      end

      test "an address that the provider does not vouch for is rejected, and nothing is created" do
        provider = unquote(provider)

        assert {:error, :email_not_verified} =
                 Accounts.get_or_register_social_user(provider, info(%{email_verified?: false}))

        assert Repo.aggregate(User, :count) == 0
      end

      test "an address that the provider does not vouch for is not linked to an existing account" do
        provider = unquote(provider)
        existing = user_fixture()

        assert {:error, :email_not_verified} =
                 Accounts.get_or_register_social_user(
                   provider,
                   info(%{email: existing.email, email_verified?: false})
                 )

        refute Map.fetch!(Repo.get!(User, existing.id), User.social_uid_field(provider))
      end

      test "linking an unconfirmed password account erases the unproven password" do
        provider = unquote(provider)
        unconfirmed = unconfirmed_user_fixture()
        assert unconfirmed.hashed_password

        info = info(%{email: unconfirmed.email})
        assert {:ok, user} = Accounts.get_or_register_social_user(provider, info)

        assert user.confirmed_at
        assert is_nil(user.hashed_password)
        refute Accounts.get_user_by_email_and_password(unconfirmed.email, valid_user_password())
      end

      test "a name or a picture that the provider did not give leaves the ones the user has" do
        provider = unquote(provider)
        existing = user_fixture()

        {:ok, existing} =
          existing
          |> Ecto.Changeset.change(name: "Kept Name", avatar_url: "https://example.com/kept.png")
          |> Repo.update()

        info = info(%{email: existing.email, name: nil, avatar_url: nil})

        assert {:ok, user} = Accounts.get_or_register_social_user(provider, info)
        assert user.name == "Kept Name"
        assert user.avatar_url == "https://example.com/kept.png"
      end
    end
  end

  describe "get_or_register_social_user/2 with both providers" do
    test "the same address reached through Google and then Microsoft is one user with both ids" do
      email = unique_user_email()

      {:ok, with_google} =
        Accounts.get_or_register_social_user(:google, info(%{email: email, uid: "g-1"}))

      {:ok, with_microsoft} =
        Accounts.get_or_register_social_user(:microsoft, info(%{email: email, uid: "m-1"}))

      assert with_google.id == with_microsoft.id
      assert with_microsoft.google_uid == "g-1"
      assert with_microsoft.microsoft_uid == "m-1"
      assert Repo.aggregate(User, :count) == 1
    end

    test "an id of one provider is not taken for an id of the other" do
      {:ok, google_user} =
        Accounts.get_or_register_social_user(:google, info(%{uid: "same-id"}))

      {:ok, microsoft_user} =
        Accounts.get_or_register_social_user(:microsoft, info(%{uid: "same-id"}))

      refute google_user.id == microsoft_user.id
    end

    test "an id belongs to one user only" do
      {:ok, first} = Accounts.get_or_register_social_user(:microsoft, info(%{uid: "taken"}))
      other = user_fixture()

      changeset = User.social_changeset(other, :microsoft, info(%{uid: "taken"}))

      assert {:error, changeset} = Repo.update(changeset)
      assert %{microsoft_uid: ["has already been taken"]} = errors_on(changeset)
      assert first.microsoft_uid == "taken"
    end
  end
end
