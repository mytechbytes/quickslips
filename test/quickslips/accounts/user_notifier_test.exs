defmodule QuickSlips.Accounts.UserNotifierTest do
  # Changes the application environment, which every test shares.
  use ExUnit.Case, async: false

  alias QuickSlips.Accounts.{User, UserNotifier}

  setup do
    previous = Application.fetch_env!(:quickslips, :mail_from)
    Application.put_env(:quickslips, :mail_from, "no-reply@mail.example.test")
    on_exit(fn -> Application.put_env(:quickslips, :mail_from, previous) end)
  end

  test "emails come from the configured address" do
    user = %User{email: "person@example.test", confirmed_at: ~U[2026-01-01 00:00:00Z]}

    assert {:ok, email} = UserNotifier.deliver_login_instructions(user, "http://localhost/link")
    assert email.from == {"QuickSlips", "no-reply@mail.example.test"}
    assert email.to == [{"", "person@example.test"}]
  end
end
