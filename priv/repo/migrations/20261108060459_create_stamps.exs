defmodule QuickSlips.Repo.Migrations.CreateStamps do
  use Ecto.Migration

  # The revenue stamps a user keeps (their own picture of one), to choose on a receipt that has a place for it. A
  # document remembers the choice, so "Download again" in the history draws the same stamp: a saved one
  # (`stamp_id`), or one of the stamps that the site provides (`stamp_system`, the name of its file in priv/images/stamps), or neither (the empty box).
  def change do
    create table(:stamps) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      # The stored picture, a path inside the uploads folder ("12/ab12cd34ef567890.png").
      add :path, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:stamps, ["user_id", "lower(name)"],
             name: :stamps_user_id_lower_name_index
           )

    # If a stamp is deleted, the documents that used it stay and lose only the picture.
    alter table(:documents) do
      add :stamp_id, references(:stamps, on_delete: :nilify_all)
      add :stamp_system, :string
    end

    create index(:documents, [:stamp_id])
  end
end
