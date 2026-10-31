defmodule QuickSlips.Quota do
  @moduledoc """
  Daily download counters, one row per (key, IST day).
  """
  import Ecto.Query

  alias QuickSlips.Quota.Counter
  alias QuickSlips.Repo

  # IST is UTC+5:30 all year (no daylight saving), so no time zone database is needed.
  @ist_offset_seconds 5 * 3600 + 30 * 60

  def limits, do: Map.new(Application.fetch_env!(:quickslips, :quota))

  @doc "The current calendar date in India."
  def today_ist(now \\ DateTime.utc_now()) do
    now |> DateTime.add(@ist_offset_seconds, :second) |> DateTime.to_date()
  end

  @doc """
  Atomically uses one download for `key`. Returns `{:ok, remaining}` or
  `{:error, :limit_reached}`.
  """
  # A function with several clauses and a default argument needs this "head" line.
  def check_and_increment(key, limit, now \\ DateTime.utc_now())

  def check_and_increment(key, limit, now) when limit > 0 do
    day = today_ist(now)
    stamp = DateTime.truncate(now, :second)

    on_conflict =
      from(c in Counter,
        where: c.count < ^limit,
        update: [inc: [count: 1], set: [updated_at: ^stamp]]
      )

    row = %{key: key, day: day, count: 1, inserted_at: stamp, updated_at: stamp}

    case Repo.insert_all(Counter, [row],
           on_conflict: on_conflict,
           conflict_target: [:key, :day],
           returning: [:count]
         ) do
      {1, [%{count: count}]} -> {:ok, limit - count}
      {0, _} -> {:error, :limit_reached}
    end
  end

  def check_and_increment(_key, _limit, _now), do: {:error, :limit_reached}

  @doc "Gives one download back (used when compilation fails)."
  def refund(key, now \\ DateTime.utc_now()) do
    day = today_ist(now)

    from(c in Counter, where: c.key == ^key and c.day == ^day and c.count > 0)
    |> Repo.update_all(inc: [count: -1])

    :ok
  end

  @doc "Downloads left today for `key` (read-only; for the badge)."
  def remaining(key, limit, now \\ DateTime.utc_now()) do
    day = today_ist(now)

    used =
      Repo.one(from c in Counter, where: c.key == ^key and c.day == ^day, select: c.count) || 0

    max(limit - used, 0)
  end
end
