defmodule QuickSlips.Repo.Migrations.CreateDocuments do
  use Ecto.Migration

  def change do
    create table(:documents) do
      add :slug, :string, null: false
      add :template, :string, null: false
      add :title, :string, null: false
      add :data, :map, null: false, default: %{}
      add :user_id, references(:users, on_delete: :delete_all), null: false

      # The saved business whose logo and signature were on the document. If the business is deleted the
      # document stays, and loses only the pictures.
      add :business_id, references(:businesses, on_delete: :nilify_all)

      timestamps(type: :utc_datetime)
    end

    # The history page asks for one user's documents, newest first.
    create index(:documents, [:user_id, :inserted_at])
    create index(:documents, [:business_id])
  end
end
