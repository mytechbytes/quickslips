defmodule QuickSlips.Repo do
  use Ecto.Repo,
    otp_app: :quickslips,
    adapter: Ecto.Adapters.Postgres
end
