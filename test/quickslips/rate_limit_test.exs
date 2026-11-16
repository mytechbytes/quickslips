defmodule QuickSlips.RateLimitTest do
  # Not async: the tests set the rules, which belong to the whole application.
  use ExUnit.Case, async: false

  import QuickSlips.RateLimitHelpers

  alias QuickSlips.RateLimit

  test "the hits within the limit pass, the next one is turned away with the time to wait" do
    put_limit(:generate, 3, 60)
    key = unique_key()

    assert :ok = RateLimit.hit(:generate, key)
    assert :ok = RateLimit.hit(:generate, key)
    assert :ok = RateLimit.hit(:generate, key)

    assert {:error, seconds} = RateLimit.hit(:generate, key)
    assert seconds in 1..60
  end

  test "each key counts for itself, and so does each rule" do
    put_limit(:generate, 1, 60)
    put_limit(:api, 1, 60)
    one = unique_key()
    other = unique_key()

    assert :ok = RateLimit.hit(:generate, one)
    assert {:error, _} = RateLimit.hit(:generate, one)

    assert :ok = RateLimit.hit(:generate, other)
    assert :ok = RateLimit.hit(:api, one)
  end

  test "count/2 reads without counting, and full?/2 says when the limit is reached" do
    put_limit(:login_captcha, 2, 60)
    key = unique_key()

    assert RateLimit.count(:login_captcha, key) == 0
    refute RateLimit.full?(:login_captcha, key)

    RateLimit.hit(:login_captcha, key)
    assert RateLimit.count(:login_captcha, key) == 1
    assert RateLimit.count(:login_captcha, key) == 1
    refute RateLimit.full?(:login_captcha, key)

    RateLimit.hit(:login_captcha, key)
    assert RateLimit.full?(:login_captcha, key)
  end

  test "forget/2 clears the count of one key and leaves the others" do
    put_limit(:login_email, 1, 60)
    one = unique_key()
    other = unique_key()
    RateLimit.hit(:login_email, one)
    RateLimit.hit(:login_email, other)

    assert :ok = RateLimit.forget(:login_email, one)

    assert RateLimit.count(:login_email, one) == 0
    assert RateLimit.count(:login_email, other) == 1
    assert :ok = RateLimit.hit(:login_email, one)
  end

  test "a key may be any term, a tuple for one" do
    put_limit(:mail_email, 1, 60)
    key = {:register, unique_key()}

    assert :ok = RateLimit.hit(:mail_email, key)
    assert {:error, _} = RateLimit.hit(:mail_email, key)
  end

  test "the sweep drops the counters of windows that are over and keeps the others" do
    put_limit(:mail_all, 5, 3600)
    now = System.system_time(:millisecond)
    key = unique_key()
    RateLimit.hit(:mail_all, key)

    # A counter whose window ended an hour ago, put in by hand.
    old = {{:mail_all, key, 1}, 4, now - 3_600_000}
    :ets.insert(QuickSlips.RateLimit, old)

    send(Process.whereis(RateLimit), :sweep)
    # The process has handled the message when it answers this call.
    _ = :sys.get_state(RateLimit)

    assert :ets.lookup(QuickSlips.RateLimit, {:mail_all, key, 1}) == []
    assert RateLimit.count(:mail_all, key) == 1
  end

  test "the rules have limits, and the configuration can change them" do
    assert %{generate: {_hits, _seconds}, login_ip: _, mail_email: _} = RateLimit.limits()

    put_limit(:generate, 7, 11)
    assert %{generate: {7, 11}} = RateLimit.limits()
  end
end
