defmodule QuickSlips.Stamps.Stamp do
  use Ecto.Schema
  import Ecto.Changeset

  schema "stamps" do
    field :name, :string
    # The stored picture, a path inside the uploads folder. Only our upload code sets it.
    field :path, :string
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @max_name 40

  def max_name_length, do: @max_name

  @doc """
  Checks the name the user gave. The owner and the picture are not cast from the form: the context sets them on
  the struct before this runs.
  """
  def changeset(stamp, attrs) do
    stamp
    |> cast(attrs, [:name])
    |> update_change(:name, &String.trim/1)
    |> validate_required([:name])
    |> validate_length(:name, max: @max_name)
    |> unique_constraint(:name,
      name: :stamps_user_id_lower_name_index,
      message: "is already used by another of your stamps"
    )
  end
end
