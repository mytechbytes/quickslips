defmodule QuickSlips.QuotaTest do
  use QuickSlips.DataCase

  alias QuickSlips.Quota

  describe "today_ist/1" do
    test "the day rolls over at 18:30 UTC (midnight in India)" do
      assert Quota.today_ist(~U[2026-10-19 18:29:59Z]) == ~D[2026-10-19]
      assert Quota.today_ist(~U[2026-10-19 18:30:00Z]) == ~D[2026-10-20]
    end
  end

  describe "check_and_increment/3" do
    test "allows exactly `limit` downloads per day" do
      now = ~U[2026-10-19 06:00:00Z]
      assert {:ok, 1} = Quota.check_and_increment("v:a", 2, now)
      assert {:ok, 0} = Quota.check_and_increment("v:a", 2, now)
      assert {:error, :limit_reached} = Quota.check_and_increment("v:a", 2, now)
    end

    test "resets after midnight IST" do
      before_midnight = ~U[2026-10-19 18:29:00Z]
      after_midnight = ~U[2026-10-19 18:31:00Z]

      assert {:ok, 0} = Quota.check_and_increment("v:b", 1, before_midnight)
      assert {:error, :limit_reached} = Quota.check_and_increment("v:b", 1, before_midnight)
      assert {:ok, 0} = Quota.check_and_increment("v:b", 1, after_midnight)
    end

    test "keys are independent" do
      now = ~U[2026-10-19 06:00:00Z]
      assert {:ok, 0} = Quota.check_and_increment("v:c", 1, now)
      assert {:ok, 0} = Quota.check_and_increment("v:d", 1, now)
    end

    test "refund gives a download back" do
      now = ~U[2026-10-19 06:00:00Z]
      assert {:ok, 0} = Quota.check_and_increment("v:e", 1, now)
      Quota.refund("v:e", now)
      assert {:ok, 0} = Quota.check_and_increment("v:e", 1, now)
    end
  end
end
