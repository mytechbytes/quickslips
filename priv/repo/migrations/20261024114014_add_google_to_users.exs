defmodule QuickSlips.Repo.Migrations.AddGoogleToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :google_uid, :string
      add :name, :string
      add :avatar_url, :text
    end

    create unique_index(:users, [:google_uid])
  end
end
