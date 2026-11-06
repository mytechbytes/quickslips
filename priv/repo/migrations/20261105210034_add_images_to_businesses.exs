defmodule QuickSlips.Repo.Migrations.AddImagesToBusinesses do
  use Ecto.Migration

  def change do
    alter table(:businesses) do
      add :logo_path, :string
      add :signature_path, :string
    end
  end
end
