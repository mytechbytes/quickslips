defmodule QuickSlips.RateLimit do
  @moduledoc """
  Counts how often something happens in a short time, to say "slow down" to whoever does it too often. The daily
  free downloads (`QuickSlips.Quota`) live in the database and last a day; these counters are for minutes: a burst
  of requests, a run of wrong passwords, a flood of e-mails.

  A counter is kept per *key* (any term: `{:generate, "203.0.113.9"}`) and per *window* of fixed length. The first hit
  in a window starts a count at 1, and when the window ends the count is forgotten. This is the simplest way to count,
  and a burst that straddles the end of a window may get up to twice the limit through: fine for a brake, not
  meant as an exact meter.

  The counts are in memory (an ETS table owned by this process). They are lost when the app restarts and are not shared
  between machines, which suits a single app container; with several machines each would count on its own.

  The limit of each named rule is in `limits/0` and can be changed with `config :quickslips, :rate_limits`, as
  `name: {hits, seconds}`. The tests turn them up so that a test run from one address does not meet them.
  """
  use GenServer

  @table __MODULE__

  # How often the counters of windows that are over are thrown away.
  @sweep_every :timer.minutes(1)

  # name: {hits allowed, in this many seconds}
  @defaults [
    # POST /api/generate: a PDF costs a Typst run. The daily quota is the real limit; this stops a burst.
    generate: {30, 60},
    # Every other call of /api, before the session is even read.
    api: {120, 60},
    # Wrong passwords, counted from one address and for one e-mail address. Many people can share an address (a
    # phone company gives one to hundreds), so the limit of an address is higher than the limit of one account.
    login_ip: {30, 900},
    login_email: {10, 900},
    # After this many wrong passwords from one address the log-in asks for the Turnstile check (it is not a lock).
    login_captcha: {3, 900},
    # E-mails the site sends for the log-in and the sign-up pages: per address of the visitor, per address typed,
    # and in all (what the SMTP account of the site can bear).
    mail_ip: {20, 3600},
    mail_email: {3, 3600},
    mail_all: {600, 3600}
  ]

  ## The counters

  @doc "The rules and their limits: `%{name => {hits, seconds}}`."
  def limits,
    do: Map.merge(Map.new(@defaults), Map.new(Application.get_env(:quickslips, :rate_limits, [])))

  @doc """
  Counts one hit of `key` under the rule `name`. Returns `:ok` while the count is within the limit of the rule, and
  `{:error, seconds}` (the time until the window ends) once it is over.
  """
  def hit(name, key) do
    {limit, seconds} = Map.fetch!(limits(), name)
    window = seconds * 1000
    now = System.system_time(:millisecond)
    id = div(now, window)
    ends_at = (id + 1) * window

    count = :ets.update_counter(@table, {name, key, id}, {2, 1}, {{name, key, id}, 0, ends_at})

    if count <= limit, do: :ok, else: {:error, seconds_left(ends_at - now)}
  rescue
    # The table is gone (the process that owns it is being restarted): a brake that is broken lets everything through
    # for that moment, rather than taking the site down with it.
    ArgumentError -> :ok
  end

  @doc "How many seconds the current window of the rule `name` has left: what to tell somebody who was turned away."
  def retry_after(name) do
    {_limit, seconds} = Map.fetch!(limits(), name)
    window = seconds * 1000
    now = System.system_time(:millisecond)
    seconds_left((div(now, window) + 1) * window - now)
  end

  @doc "How many hits `key` has in the current window of the rule `name`, without counting one."
  def count(name, key) do
    {_limit, seconds} = Map.fetch!(limits(), name)
    id = div(System.system_time(:millisecond), seconds * 1000)

    case :ets.lookup(@table, {name, key, id}) do
      [{_, count, _ends_at}] -> count
      [] -> 0
    end
  rescue
    ArgumentError -> 0
  end

  @doc "Whether the count of `key` under `name` has reached its limit (the next hit would be refused)."
  def full?(name, key) do
    {limit, _seconds} = Map.fetch!(limits(), name)
    count(name, key) >= limit
  end

  @doc "Forgets the count of `key` under the rule `name` (a right password wipes the wrong ones)."
  def forget(name, key) do
    :ets.match_delete(@table, {{name, key, :_}, :_, :_})
    :ok
  rescue
    ArgumentError -> :ok
  end

  defp seconds_left(milliseconds), do: max(div(milliseconds + 999, 1000), 1)

  ## The process that owns the table

  def start_link(_options), do: GenServer.start_link(__MODULE__, nil, name: __MODULE__)

  @impl true
  def init(nil) do
    :ets.new(@table, [
      :named_table,
      :public,
      :set,
      write_concurrency: true,
      read_concurrency: true
    ])

    schedule_sweep()
    {:ok, nil}
  end

  @impl true
  def handle_info(:sweep, state) do
    now = System.system_time(:millisecond)
    :ets.select_delete(@table, [{{:_, :_, :"$1"}, [{:<, :"$1", now}], [true]}])
    schedule_sweep()
    {:noreply, state}
  end

  defp schedule_sweep, do: Process.send_after(self(), :sweep, @sweep_every)
end
