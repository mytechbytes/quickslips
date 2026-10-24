defmodule QuickSlips.AccountsRegistrationTest do
  use QuickSlips.DataCase

  alias QuickSlips.Accounts

  import QuickSlips.AccountsFixtures

  describe "register_user/1 with a password" do
    test "stores a hash and not the password" do
      {:ok, user} = Accounts.register_user(valid_user_attributes())
      assert is_binary(user.hashed_password)
      assert is_nil(user.password)
    end

    test "rejects a mismatched confirmation" do
      {:error, changeset} =
        Accounts.register_user(valid_user_attributes(password_confirmation: "something else!"))

      assert %{password_confirmation: ["does not match password"]} = errors_on(changeset)
    end
  end

  describe "confirm_user_with_password/2" do
    test "needs the right password" do
      user = unconfirmed_user_fixture()
      token = extract_user_token(fn url -> Accounts.deliver_login_instructions(user, url) end)

      assert {:error, :invalid} = Accounts.confirm_user_with_password(token, "not the password")

      assert {:ok, {confirmed, _}} =
               Accounts.confirm_user_with_password(token, valid_user_password())

      assert confirmed.confirmed_at
    end

    test "link tokens can only be used once" do
      user = unconfirmed_user_fixture()
      token = extract_user_token(fn url -> Accounts.deliver_login_instructions(user, url) end)

      assert {:ok, _} = Accounts.confirm_user_with_password(token, valid_user_password())

      assert {:error, :invalid} =
               Accounts.confirm_user_with_password(token, valid_user_password())
    end

    test "rejects an invalid token" do
      assert {:error, :invalid} =
               Accounts.confirm_user_with_password("oops", valid_user_password())
    end

    test "does not apply to an already confirmed user" do
      user = user_fixture()
      {token, _hashed_token} = generate_user_magic_link_token(user)

      assert {:error, :invalid} =
               Accounts.confirm_user_with_password(token, valid_user_password())
    end
  end
end
