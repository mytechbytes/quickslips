defmodule QuickSlips.Documents.Document do
  use Ecto.Schema
  import Ecto.Changeset

  schema "documents" do
    field :slug, :string
    field :template, :string
    field :title, :string
    field :data, :map

    # The language the document was made in, and what else shaped it: `%{"country" => "in", "currency" => "INR"}`.
    field :language, :string, default: "en"
    field :options, :map, default: %{}
    field :user_id, :id
    field :business_id, :id

    # The signature that was drawn on the document (a saved one, or none: the place to sign by hand).
    field :signature_id, :id

    # The revenue stamp that was drawn on it: a saved one, the default stamp of the site, or neither (the empty box).
    field :stamp_id, :id
    field :stamp_system, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(document, attrs, user_scope) do
    document
    |> cast(attrs, [:slug, :template, :title, :data, :language, :options])
    |> validate_required([:slug, :template, :title, :data, :language])
    |> validate_inclusion(:language, QuickSlips.Locales.languages())
    |> validate_length(:title, max: 255)
    |> put_change(:user_id, user_scope.user.id)
  end

  @doc """
  Sets the saved business. Like `user_id`, it is not cast from `attrs`: the caller found the business through
  the user's scope, and that is the only way it may get here.
  """
  def put_business(changeset, nil), do: changeset
  def put_business(changeset, %{id: id}), do: put_change(changeset, :business_id, id)

  @doc "Sets the signature that was drawn on the document, found through the user's scope like the business."
  def put_signature(changeset, nil), do: changeset
  def put_signature(changeset, %{id: id}), do: put_change(changeset, :signature_id, id)

  @doc "Sets the revenue stamp: `nil` (the empty box), `{:system, id}` (one the site provides), or a saved stamp."
  def put_stamp(changeset, nil), do: changeset
  def put_stamp(changeset, {:system, id}), do: put_change(changeset, :stamp_system, id)
  def put_stamp(changeset, %{id: id}), do: put_change(changeset, :stamp_id, id)
end
