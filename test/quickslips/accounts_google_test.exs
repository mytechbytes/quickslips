defmodule QuickSlips.AccountsGoogleTest do
  use QuickSlips.DataCase

  alias QuickSlips.Accounts
  alias QuickSlips.Accounts.User
  alias QuickSlips.Repo

  import QuickSlips.AccountsFixtures

  defp google_info(attrs \\ %{}) do
    Map.merge(
      %{
        google_uid: "g-#{System.unique_integer([:positive])}",
        email: unique_user_email(),
        name: "Gina Google",
        avatar_url: "https://example.com/gina.png",
        email_verified?: true
      },
      attrs
    )
  end

  describe "get_or_register_google_user/1" do
    test "case 1: a new Google user is created, confirmed, with no password" do
      info = google_info()

      assert {:ok, user} = Accounts.get_or_register_google_user(info)
      assert user.confirmed_at
      assert user.google_uid == info.google_uid
      assert is_nil(user.hashed_password)
    end

    test "case 2: an existing password user with the same email is linked, not duplicated" do
      existing = user_fixture()
      info = google_info(%{email: existing.email})

      assert {:ok, user} = Accounts.get_or_register_google_user(info)
      assert user.id == existing.id
      assert user.google_uid == info.google_uid
      assert Repo.aggregate(User, :count) == 1
      # their password still works
      assert Accounts.get_user_by_email_and_password(existing.email, valid_user_password())
    end

    test "case 3: a Google-only user can set a password later" do
      {:ok, user} = Accounts.get_or_register_google_user(google_info())

      {:ok, {user, _expired}} =
        Accounts.update_user_password(user, %{
          password: "P@ssword",
          password_confirmation: "P@ssword"
        })

      assert Accounts.get_user_by_email_and_password(user.email, "P@ssword")
    end

    test "a second login finds the same user by google_uid" do
      info = google_info()
      {:ok, first} = Accounts.get_or_register_google_user(info)
      {:ok, second} = Accounts.get_or_register_google_user(info)
      assert first.id == second.id
    end

    test "an unverified Google email is rejected" do
      assert {:error, :email_not_verified} =
               Accounts.get_or_register_google_user(google_info(%{email_verified?: false}))
    end

    test "linking an unconfirmed password account erases the unproven password" do
      unconfirmed = unconfirmed_user_fixture()
      assert unconfirmed.hashed_password

      info = google_info(%{email: unconfirmed.email})
      assert {:ok, user} = Accounts.get_or_register_google_user(info)

      assert user.confirmed_at
      assert is_nil(user.hashed_password)
      refute Accounts.get_user_by_email_and_password(unconfirmed.email, valid_user_password())
    end
  end
end
