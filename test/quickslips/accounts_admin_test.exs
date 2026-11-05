defmodule QuickSlips.AccountsAdminTest do
  use QuickSlips.DataCase

  alias QuickSlips.Accounts

  import QuickSlips.AccountsFixtures

  setup do
    previous = Application.get_env(:quickslips, :admin_emails)
    on_exit(fn -> Application.put_env(:quickslips, :admin_emails, previous) end)
  end

  test "nobody is an admin until the list says so" do
    Application.put_env(:quickslips, :admin_emails, [])
    refute Accounts.admin?(user_fixture())
  end

  test "a confirmed user on the list is an admin, whatever the case of the address" do
    user = user_fixture()
    Application.put_env(:quickslips, :admin_emails, [String.downcase(user.email)])

    assert Accounts.admin?(user)
    assert Accounts.admin?(%{user | email: String.upcase(user.email)})
  end

  test "an unconfirmed account does not count, even with its address on the list" do
    user = unconfirmed_user_fixture()
    Application.put_env(:quickslips, :admin_emails, [String.downcase(user.email)])

    refute Accounts.admin?(user)
  end

  test "no user, no admin" do
    refute Accounts.admin?(nil)
  end
end
