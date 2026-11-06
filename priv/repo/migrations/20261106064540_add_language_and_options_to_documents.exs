defmodule QuickSlips.Repo.Migrations.AddLanguageAndOptionsToDocuments do
  use Ecto.Migration

  # A document remembers the language it was made in and the choices that shaped it (the country and the
  # currency for now), so "download again" and "edit and regenerate" give back what the user made.
  def up do
    alter table(:documents) do
      add :language, :string, null: false, default: "en"
      add :options, :map, null: false, default: %{}
    end

    # Every document made so far was made for India, in English.
    execute ~s(UPDATE documents SET options = '{"country": "in", "currency": "INR"}')
  end

  def down do
    alter table(:documents) do
      remove :options
      remove :language
    end
  end
end
