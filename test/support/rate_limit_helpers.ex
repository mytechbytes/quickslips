defmodule QuickSlips.RateLimitHelpers do
  @moduledoc """
  For tests of a brake of `QuickSlips.RateLimit`. In the tests every rule is turned far up (`config/test.exs`), because
  all requests come from one address and the counters are shared by every test. A test that wants to meet a brake sets
  the rule it needs here, and the rule goes back when the test ends. The rules belong to the whole application, so a
  test module that uses this must not be `async`.
  """
  import ExUnit.Callbacks, only: [on_exit: 1]

  @doc "Sets one rule: `put_limit(:generate, 2, 60)` allows 2 hits in 60 seconds."
  def put_limit(name, hits, seconds) do
    previous = Application.get_env(:quickslips, :rate_limits, [])
    Application.put_env(:quickslips, :rate_limits, Keyword.put(previous, name, {hits, seconds}))
    on_exit(fn -> Application.put_env(:quickslips, :rate_limits, previous) end)
  end

  @doc "A key no other test uses, so that the counters of one test cannot be seen by another."
  def unique_key, do: "test-#{System.unique_integer([:positive])}"

  @doc "An address of the documentation range of IPv4 that no other test uses."
  def unique_ip do
    n = System.unique_integer([:positive])
    {198, 51, rem(div(n, 250), 250), rem(n, 250) + 1}
  end
end
