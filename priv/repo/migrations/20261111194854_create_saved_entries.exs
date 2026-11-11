defmodule QuickSlips.Repo.Migrations.CreateSavedEntries do
  use Ecto.Migration

  # The details of one section of a bill's form that a user keeps to fill it again (an employee, a driver): the
  # section is the `key` ("driver-salary-receipt/business"), the `name` is what the picker shows, and `data` holds the
  # value of each field of the section.
  def change do
    create table(:saved_entries) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :key, :string, null: false
      add :name, :string, null: false
      add :data, :map, null: false, default: %{}

      timestamps(type: :utc_datetime)
    end

    create unique_index(:saved_entries, ["user_id", "key", "lower(name)"],
             name: :saved_entries_user_id_key_lower_name_index
           )
  end
end
