defmodule QuickSlips.Repo.Migrations.AddMicrosoftUidToUsers do
  use Ecto.Migration

  # Like google_uid: the id Microsoft gives to the person, so that the next sign-in finds the same user.
  def change do
    alter table(:users) do
      add :microsoft_uid, :string
    end

    create unique_index(:users, [:microsoft_uid])
  end
end
