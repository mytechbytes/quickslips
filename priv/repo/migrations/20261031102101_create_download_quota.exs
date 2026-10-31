defmodule QuickSlips.Repo.Migrations.CreateDownloadQuota do
  use Ecto.Migration

  def change do
    create table(:download_quota) do
      add :key, :string, null: false
      add :day, :date, null: false
      add :count, :integer, null: false, default: 0
      timestamps(type: :utc_datetime)
    end

    create unique_index(:download_quota, [:key, :day])
  end
end
