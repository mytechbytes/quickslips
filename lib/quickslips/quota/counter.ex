defmodule QuickSlips.Quota.Counter do
  use Ecto.Schema

  schema "download_quota" do
    field :key, :string
    field :day, :date
    field :count, :integer, default: 0
    timestamps(type: :utc_datetime)
  end
end
