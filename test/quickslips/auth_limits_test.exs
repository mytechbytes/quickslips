defmodule QuickSlips.AuthLimitsTest do
  # Not async: the tests set the rules of the rate limiter, which belong to the whole application.
  use ExUnit.Case, async: false

  import QuickSlips.RateLimitHelpers

  alias QuickSlips.AuthLimits
  alias QuickSlips.RateLimit

  defp email, do: "someone-#{System.unique_integer([:positive])}@example.com"

  describe "check_mail/2" do
    test "lets a visitor ask for a few e-mails, then turns them away" do
      put_limit(:mail_ip, 2, 3600)
      ip = unique_key()

      assert :ok = AuthLimits.check_mail(ip, email())
      assert :ok = AuthLimits.check_mail(ip, email())
      assert {:error, {:slow_down, seconds}} = AuthLimits.check_mail(ip, email())
      assert seconds in 1..3600
    end

    test "turns away an e-mail address that is asked for too often, whoever asks and however it is written" do
      put_limit(:mail_email, 2, 3600)
      address = email()

      assert :ok = AuthLimits.check_mail(unique_key(), address)
      assert :ok = AuthLimits.check_mail(unique_key(), "  " <> String.upcase(address) <> " ")
      assert {:error, {:slow_down, _}} = AuthLimits.check_mail(unique_key(), address)

      # Another address is not touched
      assert :ok = AuthLimits.check_mail(unique_key(), email())
    end

    test "turns everybody away when the whole site has sent too many" do
      put_limit(:mail_all, 1, 3600)

      # The count of the whole site is shared: use a rule of its own for this test, and start from nothing.
      RateLimit.forget(:mail_all, :all)

      assert :ok = AuthLimits.check_mail(unique_key(), email())
      assert {:error, {:slow_down, _}} = AuthLimits.check_mail(unique_key(), email())
    end

    test "a visitor who is over their own limit does not use up the limit of the address or of the site" do
      put_limit(:mail_ip, 1, 3600)
      put_limit(:mail_email, 2, 3600)
      ip = unique_key()
      address = email()

      assert :ok = AuthLimits.check_mail(ip, address)
      # Turned away by the visitor's own limit: not counted for the address
      assert {:error, _} = AuthLimits.check_mail(ip, address)
      assert {:error, _} = AuthLimits.check_mail(ip, address)

      assert :ok = AuthLimits.check_mail(unique_key(), address)
    end
  end

  describe "the log-in with a password" do
    test "is turned away after too many wrong passwords from one address" do
      put_limit(:login_ip, 2, 900)
      ip = unique_key()

      assert :ok = AuthLimits.check_login(ip, email())
      AuthLimits.record_login_failure(ip, email())
      assert :ok = AuthLimits.check_login(ip, email())
      AuthLimits.record_login_failure(ip, email())

      assert {:error, {:slow_down, seconds}} = AuthLimits.check_login(ip, email())
      assert seconds in 1..900
      assert :ok = AuthLimits.check_login(unique_key(), email())
    end

    test "is turned away after too many wrong passwords for one account, from whichever address" do
      put_limit(:login_email, 2, 900)
      address = email()

      AuthLimits.record_login_failure(unique_key(), address)
      AuthLimits.record_login_failure(unique_key(), String.upcase(address))

      assert {:error, {:slow_down, _}} = AuthLimits.check_login(unique_key(), address)
      assert :ok = AuthLimits.check_login(unique_key(), email())
    end

    test "a right password forgets the wrong ones of the account, and only those" do
      put_limit(:login_email, 2, 900)
      put_limit(:login_ip, 2, 900)
      address = email()
      ip = unique_key()

      AuthLimits.record_login_failure(ip, address)
      AuthLimits.record_login_failure(ip, address)
      assert {:error, _} = AuthLimits.check_login(unique_key(), address)

      AuthLimits.clear_login_failures(address)

      assert :ok = AuthLimits.check_login(unique_key(), address)
      # The address of the visitor keeps its count
      assert {:error, _} = AuthLimits.check_login(ip, email())
    end

    test "asks for the Turnstile check after a few wrong passwords from one address, and only from it" do
      put_limit(:login_captcha, 2, 900)
      ip = unique_key()

      refute AuthLimits.captcha_required?(ip)
      AuthLimits.record_login_failure(ip, email())
      refute AuthLimits.captcha_required?(ip)
      AuthLimits.record_login_failure(ip, email())

      assert AuthLimits.captcha_required?(ip)
      refute AuthLimits.captcha_required?(unique_key())
    end
  end
end
