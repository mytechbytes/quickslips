defmodule QuickSlips.Businesses.Business do
  use Ecto.Schema
  import Ecto.Changeset

  schema "businesses" do
    field :name, :string
    field :address, :string
    field :gstin, :string
    field :logo_path, :string

    # The signature that is chosen on a bill when this business is: one of the user's `Signatures`.
    field :signature_id, :id
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  # The shape of an Indian GSTIN. The business form of the logged-in app is Indian, so this is what it checks.
  @gstin ~r/^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$/

  @doc """
  Checks what the user typed. The owner and the logo are not cast from the form.

  `opts` may hold `tax_id: {pattern, label}`: the shape of the registration number of the country a bill is made
  for (`Regions` has it: "NIF" in Spain), or `{nil, label}` for a country that has none to check. Without it the
  number has to be a GSTIN.
  """
  def changeset(business, attrs, user_scope, opts \\ []) do
    {pattern, label} = Keyword.get(opts, :tax_id, {@gstin, "GSTIN (15 characters)"})

    business
    |> cast(attrs, [:name, :address, :gstin, :signature_id])
    |> validate_required([:name])
    |> put_change(:user_id, user_scope.user.id)
    |> update_change(:gstin, fn
      nil -> nil
      gstin -> gstin |> String.trim() |> String.upcase()
    end)
    |> validate_tax_id(pattern, label)
  end

  defp validate_tax_id(changeset, nil, _label), do: changeset

  defp validate_tax_id(changeset, pattern, label) do
    validate_format(changeset, :gstin, pattern, message: "is not a valid #{label}")
  end

  @doc """
  Sets the stored logo path. Only our upload code calls this, with a path it made itself, which is
  why `changeset/4` does not cast `logo_path` from the form.
  """
  def put_images(changeset, images) do
    change(changeset, Map.take(images, [:logo_path]))
  end
end
