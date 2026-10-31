defmodule QuickSlips.Downloads do
  @moduledoc "Decides whether a caller may generate another PDF today."

  alias QuickSlips.Quota

  @type caller :: %{user: struct() | nil, visitor_id: String.t(), ip: String.t()}

  @doc """
  Reserves one download. Returns `{:ok, grant}` (pass it to `refund/1` if the render
  fails) or `{:error, {:limit_reached, :anonymous | :user}}`.
  """
  def reserve(%{user: %{id: id}}) do
    key = "u:#{id}"

    case Quota.check_and_increment(key, Quota.limits().user) do
      {:ok, remaining} -> {:ok, %{keys: [key], remaining: remaining}}
      {:error, :limit_reached} -> {:error, {:limit_reached, :user}}
    end
  end

  def reserve(%{visitor_id: vid, ip: ip}) do
    limits = Quota.limits()
    visitor_key = "v:#{vid}"
    ip_key = "ip:#{ip}"

    with {:ok, remaining} <- Quota.check_and_increment(visitor_key, limits.anonymous),
         :ok <- reserve_ip(ip_key, limits.ip, visitor_key) do
      {:ok, %{keys: [visitor_key, ip_key], remaining: remaining}}
    else
      {:error, :limit_reached} -> {:error, {:limit_reached, :anonymous}}
    end
  end

  # If the IP ceiling blocks the request, give the visitor's own count back.
  def reserve_ip(ip_key, limit, visitor_key) do
    case Quota.check_and_increment(ip_key, limit) do
      {:ok, _remaining} ->
        :ok

      {:error, :limit_reached} = error ->
        Quota.refund(visitor_key)
        error
    end
  end

  def refund(%{keys: keys}), do: Enum.each(keys, &Quota.refund/1)

  @doc "Read-only status for the UI badge: `%{remaining: n, limit: n, tier: :anonymous | :user}`."
  def status(%{user: %{id: id}}) do
    limit = Quota.limits().user
    %{remaining: Quota.remaining("u:#{id}", limit), limit: limit, tier: :user}
  end

  def status(%{visitor_id: vid, ip: ip}) do
    limits = Quota.limits()

    remaining =
      min(Quota.remaining("v:#{vid}", limits.anonymous), Quota.remaining("ip:#{ip}", limits.ip))

    %{remaining: remaining, limit: limits.anonymous, tier: :anonymous}
  end
end
