defmodule QuickSlips.Businesses.Business do
  use Ecto.Schema
  import Ecto.Changeset

  schema "businesses" do
    field :name, :string
    field :address, :string
    field :gstin, :string
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(business, attrs, user_scope) do
    business
    |> cast(attrs, [:name, :address, :gstin])
    |> validate_required([:name, :address, :gstin])
    |> put_change(:user_id, user_scope.user.id)
    |> update_change(:gstin, fn
      nil -> nil
      gstin -> gstin |> String.trim() |> String.upcase()
    end)
    |> validate_format(
      :gstin,
      ~r/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/,
      message: "is not a valid GSTIN (15 characters)"
    )
  end
end
