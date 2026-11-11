defmodule QuickSlips.SavedEntries.SavedEntry do
  use Ecto.Schema

  schema "saved_entries" do
    field :key, :string
    field :name, :string
    field :data, :map
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end
end
