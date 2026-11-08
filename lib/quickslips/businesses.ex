defmodule QuickSlips.Businesses do
  @moduledoc """
  The Businesses context.
  """

  import Ecto.Query, warn: false
  alias QuickSlips.Repo

  alias QuickSlips.Businesses.Business
  alias QuickSlips.Accounts.Scope
  alias QuickSlips.Signatures
  alias QuickSlips.Uploads

  # The columns that hold a stored image (a path inside the uploads folder). The signature is not one of them: it
  # lives in the library of `QuickSlips.Signatures`, and the business only says which one is its default.
  @image_columns [:logo_path]

  @doc """
  Subscribes to scoped notifications about any business changes.

  The broadcasted messages match the pattern:

    * {:created, %Business{}}
    * {:updated, %Business{}}
    * {:deleted, %Business{}}

  """
  def subscribe_businesses(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(QuickSlips.PubSub, "user:#{key}:businesses")
  end

  defp broadcast_business(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(QuickSlips.PubSub, "user:#{key}:businesses", message)
  end

  @doc """
  Returns the list of businesses.

  ## Examples

      iex> list_businesses(scope)
      [%Business{}, ...]

  """
  def list_businesses(%Scope{} = scope) do
    Repo.all_by(Business, user_id: scope.user.id)
  end

  @doc "How many businesses the user has saved."
  def count_businesses(%Scope{} = scope) do
    Repo.aggregate(from(b in Business, where: b.user_id == ^scope.user.id), :count)
  end

  @doc """
  Gets a single business.

  Raises `Ecto.NoResultsError` if the Business does not exist.

  ## Examples

      iex> get_business!(scope, 123)
      %Business{}

      iex> get_business!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_business!(%Scope{} = scope, id) do
    Repo.get_by!(Business, id: id, user_id: scope.user.id)
  end

  @doc """
  Creates a business.

  `images` is what the upload code stored: `%{logo_path: "12/ab12.png"}`, with the key left out when there is
  no logo. It is a separate argument, and not part of `attrs`, because `attrs` comes from the browser and the
  paths must not. `attrs` may hold the id of a `signature_id` to use by default, which has to be one of the
  user's own.

  `opts` may hold `tax_id: {pattern, label}` (see `Business.changeset/4`).

  ## Examples

      iex> create_business(scope, %{field: value})
      {:ok, %Business{}}

      iex> create_business(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_business(%Scope{} = scope, attrs, images \\ %{}, opts \\ []) do
    with {:ok, business = %Business{}} <-
           %Business{}
           |> Business.changeset(attrs, scope, opts)
           |> validate_signature_owner(scope)
           |> Business.put_images(images)
           |> Repo.insert() do
      broadcast_business(scope, {:created, business})
      {:ok, business}
    end
  end

  @doc """
  Updates a business. A new image in `images` replaces the old one, and the old file is deleted.

  ## Examples

      iex> update_business(scope, business, %{field: new_value})
      {:ok, %Business{}}

      iex> update_business(scope, business, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_business(%Scope{} = scope, %Business{} = business, attrs, images \\ %{}, opts \\ []) do
    true = business.user_id == scope.user.id

    with {:ok, updated = %Business{}} <-
           business
           |> Business.changeset(attrs, scope, opts)
           |> validate_signature_owner(scope)
           |> Business.put_images(images)
           |> Repo.update() do
      delete_replaced_images(business, updated)
      broadcast_business(scope, {:updated, updated})
      {:ok, updated}
    end
  end

  @doc """
  Removes the logo (`kind` is `:logo`) and deletes its file. A signature is not removed here: it belongs to the
  library of `QuickSlips.Signatures`, and the business only stops using it (`signature_id: nil` in `update_business/4`).
  """
  def remove_image(%Scope{} = scope, %Business{} = business, :logo) do
    true = business.user_id == scope.user.id

    with {:ok, updated = %Business{}} <-
           business
           |> Ecto.Changeset.change(%{logo_path: nil})
           |> Repo.update() do
      delete_replaced_images(business, updated)
      broadcast_business(scope, {:updated, updated})
      {:ok, updated}
    end
  end

  # The old file of an image that was replaced or removed is not needed any more.
  defp delete_replaced_images(old, new) do
    for column <- @image_columns do
      old_path = Map.fetch!(old, column)
      if old_path && old_path != Map.fetch!(new, column), do: Uploads.delete(old_path)
    end

    :ok
  end

  @doc """
  Deletes a business.

  ## Examples

      iex> delete_business(scope, business)
      {:ok, %Business{}}

      iex> delete_business(scope, business)
      {:error, %Ecto.Changeset{}}

  """
  def delete_business(%Scope{} = scope, %Business{} = business) do
    true = business.user_id == scope.user.id

    with {:ok, business = %Business{}} <-
           Repo.delete(business) do
      Enum.each(@image_columns, &Uploads.delete(Map.fetch!(business, &1)))
      broadcast_business(scope, {:deleted, business})
      {:ok, business}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking business changes.

  ## Examples

      iex> change_business(scope, business)
      %Ecto.Changeset{data: %Business{}}

  """
  def change_business(%Scope{} = scope, %Business{} = business, attrs \\ %{}) do
    true = business.user_id == scope.user.id

    business
    |> Business.changeset(attrs, scope)
    |> validate_signature_owner(scope)
  end

  # The default signature comes from a select of the form, so its id is only as good as the browser that sent it:
  # it has to be one of this user's signatures.
  defp validate_signature_owner(changeset, scope) do
    case Ecto.Changeset.get_change(changeset, :signature_id) do
      nil ->
        changeset

      id ->
        if Signatures.owned?(scope, id),
          do: changeset,
          else:
            Ecto.Changeset.add_error(changeset, :signature_id, "is not one of your signatures")
    end
  end

  @doc """
  Saves the seller details typed on a bill's page, the quick way. `attrs` are the form's `"name"`, `"address"` and
  `"gstin"`. The business that already has this name (capital letters do not count) gets the new address and
  registration number; a name that is new makes a business. Its logo and default signature are not touched.

  Returns `{:ok, business, :created | :updated}` or `{:error, changeset}`. `opts` as in `create_business/4`.
  """
  def save_details(%Scope{} = scope, attrs, opts \\ []) do
    attrs = Map.take(attrs, ["name", "address", "gstin"])

    case find_by_name(scope, attrs["name"]) do
      nil ->
        with {:ok, business} <- create_business(scope, attrs, %{}, opts),
             do: {:ok, business, :created}

      business ->
        with {:ok, business} <- update_business(scope, business, attrs, %{}, opts),
             do: {:ok, business, :updated}
    end
  end

  defp find_by_name(scope, name) when is_binary(name) do
    wanted = name |> String.trim() |> String.downcase()

    Repo.one(
      from b in Business,
        where: b.user_id == ^scope.user.id and fragment("lower(?)", b.name) == ^wanted,
        order_by: b.id,
        limit: 1
    )
  end

  defp find_by_name(_scope, _no_name), do: nil

  @doc """
  What the renderer needs to draw the logo of a business and the signature that was chosen for the document
  (a `%QuickSlips.Signatures.Signature{}` or `nil`, which leaves the place to sign by hand):

    * `data`, the file names to add to the document's data (`%{"logo" => "logo.png", "signature" => "signature.jpg"}`), and
    * `files`, a map from each of those names to the stored file, to copy next to the template.

  An image whose file has gone missing is left out, so the document is made without it. `nil` for the business
  has no logo.
  """
  def render_assets(business, signature \\ nil, stamp \\ nil) do
    pictures = [
      logo_assets(business),
      Signatures.render_assets(signature),
      QuickSlips.Stamps.render_assets(stamp)
    ]

    %{
      data: Enum.reduce(pictures, %{}, &Map.merge(&2, &1.data)),
      files: Enum.reduce(pictures, %{}, &Map.merge(&2, &1.files))
    }
  end

  defp logo_assets(%Business{logo_path: relative}) when is_binary(relative) do
    if File.regular?(Uploads.path(relative)) do
      name = "logo" <> Path.extname(relative)
      %{data: %{"logo" => name}, files: %{name => Uploads.path(relative)}}
    else
      %{data: %{}, files: %{}}
    end
  end

  defp logo_assets(_no_logo), do: %{data: %{}, files: %{}}
end
