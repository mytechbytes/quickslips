defmodule QuickSlips.Repo.Migrations.CreateSignatures do
  use Ecto.Migration

  # A user can keep several signatures. Before, a business had exactly one (`businesses.signature_path`); now the
  # signatures are a library of their own, a business only points at its default one, and a document points at the
  # one that was drawn on it, so "Download again" in the history draws the same signature.
  def up do
    create table(:signatures) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :name, :string, null: false
      # The stored picture, a path inside the uploads folder ("12/ab12cd34ef567890.png").
      add :path, :string, null: false

      timestamps(type: :utc_datetime)
    end

    # "Owner" and "owner" are the same name. The list of a user is the only place names are looked up.
    create unique_index(:signatures, ["user_id", "lower(name)"],
             name: :signatures_user_id_lower_name_index
           )

    # If a signature is deleted, the business and the documents that used it stay and lose only the picture.
    alter table(:businesses) do
      add :signature_id, references(:signatures, on_delete: :nilify_all)
    end

    alter table(:documents) do
      add :signature_id, references(:signatures, on_delete: :nilify_all)
    end

    create index(:businesses, [:signature_id])
    create index(:documents, [:signature_id])

    # The signature each business already has becomes the first entry of its owner's library, named after the
    # business ("Sunrise Fuel Station signature"; a second business with the same name gets " 2", and so on).
    execute """
    INSERT INTO signatures (user_id, name, path, inserted_at, updated_at)
    SELECT user_id,
           CASE WHEN n = 1 THEN base ELSE left(base, 36) || ' ' || n END,
           signature_path,
           now() AT TIME ZONE 'utc',
           now() AT TIME ZONE 'utc'
    FROM (
      SELECT b.user_id,
             b.signature_path,
             left(b.name, 28) || ' signature' AS base,
             row_number() OVER (
               PARTITION BY b.user_id, lower(left(b.name, 28)) ORDER BY b.id
             ) AS n
      FROM businesses b
      WHERE b.signature_path IS NOT NULL
    ) AS found
    """

    execute """
    UPDATE businesses AS b
    SET signature_id = s.id
    FROM signatures AS s
    WHERE s.user_id = b.user_id AND s.path = b.signature_path
    """

    # A document made with a business was drawn with that business's signature, so it keeps drawing it.
    execute """
    UPDATE documents AS d
    SET signature_id = b.signature_id
    FROM businesses AS b
    WHERE d.business_id = b.id AND b.signature_id IS NOT NULL
    """

    alter table(:businesses) do
      remove :signature_path
    end
  end

  def down do
    alter table(:businesses) do
      add :signature_path, :string
    end

    execute """
    UPDATE businesses AS b
    SET signature_path = s.path
    FROM signatures AS s
    WHERE b.signature_id = s.id
    """

    alter table(:documents) do
      remove :signature_id
    end

    alter table(:businesses) do
      remove :signature_id
    end

    drop table(:signatures)
  end
end
