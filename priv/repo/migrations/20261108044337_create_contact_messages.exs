defmodule QuickSlips.Repo.Migrations.CreateContactMessages do
  use Ecto.Migration

  # What visitors write in the contact form. The owner is told by e-mail, and the message is kept here as well, so
  # that it can be found again: the page for the owner is /admin/messages.
  def change do
    create table(:contact_messages) do
      # What the sender is told and what the e-mails quote, like "K3F9-Q27A": the owner finds a message by it.
      add :reference, :string, null: false
      add :topic, :string, null: false
      add :name, :string
      add :email, :string, null: false
      add :message, :text, null: false
      # The language and country of the page the sender was on, like "es-ES".
      add :locale, :string
      # The page the message is about: a path of this site, like "/en-in/fuel-bill-generator".
      add :page, :string
      # "new" until the owner opens it, then "read", and "resolved" once it has been dealt with.
      add :status, :string, null: false, default: "new"
      # Who was logged in. The message stays if the account is deleted.
      add :user_id, references(:users, on_delete: :nilify_all)
      # When the e-mails went out; nothing means they did not (yet).
      add :owner_notified_at, :utc_datetime
      add :confirmation_sent_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:contact_messages, [:reference])
    create index(:contact_messages, [:status, :inserted_at])
    create index(:contact_messages, [:inserted_at])
    create index(:contact_messages, [:user_id])
  end
end
