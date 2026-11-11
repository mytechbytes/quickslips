defmodule QuickSlips.Repo.Migrations.AddDriverSignatureToDocuments do
  use Ecto.Migration

  # A receipt may carry two signatures: the first one chosen (`signature_id`, the employee's) and the driver's. If a
  # signature is deleted, the documents that used it stay and lose only the picture.
  def change do
    alter table(:documents) do
      add :driver_signature_id, references(:signatures, on_delete: :nilify_all)
    end
  end
end
