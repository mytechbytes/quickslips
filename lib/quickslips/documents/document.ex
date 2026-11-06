defmodule QuickSlips.Documents.Document do
  use Ecto.Schema
  import Ecto.Changeset

  schema "documents" do
    field :slug, :string
    field :template, :string
    field :title, :string
    field :data, :map
    field :user_id, :id
    field :business_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(document, attrs, user_scope) do
    document
    |> cast(attrs, [:slug, :template, :title, :data])
    |> validate_required([:slug, :template, :title, :data])
    |> validate_length(:title, max: 255)
    |> put_change(:user_id, user_scope.user.id)
  end

  @doc """
  Sets the saved business. Like `user_id`, it is not cast from `attrs`: the caller found the business through
  the user's scope, and that is the only way it may get here.
  """
  def put_business(changeset, nil), do: changeset
  def put_business(changeset, %{id: id}), do: put_change(changeset, :business_id, id)
end
