defmodule QuickSlips.DownloadsTest do
  use QuickSlips.DataCase

  alias QuickSlips.Downloads

  import QuickSlips.AccountsFixtures

  defp anon(vid, ip \\ "10.0.0.1"), do: %{user: nil, visitor_id: vid, ip: ip}

  test "anonymous visitors get 2 downloads, then are blocked" do
    assert {:ok, %{remaining: 1}} = Downloads.reserve(anon("vid-1"))
    assert {:ok, %{remaining: 0}} = Downloads.reserve(anon("vid-1"))
    assert {:error, {:limit_reached, :anonymous}} = Downloads.reserve(anon("vid-1"))
  end

  test "logged-in users get their own, larger allowance" do
    caller = %{user: user_fixture(), visitor_id: "vid-2", ip: "10.0.0.2"}

    for _ <- 1..3, do: assert({:ok, _} = Downloads.reserve(caller))
    assert {:error, {:limit_reached, :user}} = Downloads.reserve(caller)
  end

  test "the per-IP ceiling stops cookie-clearing" do
    # five different "visitors" from one IP use the ceiling of 5 ...
    for n <- 1..5, do: assert({:ok, _} = Downloads.reserve(anon("fresh-#{n}", "10.9.9.9")))

    # ... so a sixth brand-new visitor is refused, and not charged a visitor download
    assert {:error, {:limit_reached, :anonymous}} = Downloads.reserve(anon("fresh-6", "10.9.9.9"))
    assert {:ok, %{remaining: 1}} = Downloads.reserve(anon("fresh-6", "10.8.8.8"))
  end

  test "refund restores the download" do
    {:ok, grant} = Downloads.reserve(anon("vid-3", "10.0.0.3"))
    Downloads.refund(grant)
    assert %{remaining: 2} = Downloads.status(anon("vid-3", "10.0.0.3"))
  end
end
