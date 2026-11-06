defmodule QuickSlips.Businesses do
  @moduledoc """
  The Businesses context.
  """

  import Ecto.Query, warn: false
  alias QuickSlips.Repo

  alias QuickSlips.Businesses.Business
  alias QuickSlips.Accounts.Scope
  alias QuickSlips.Uploads

  # The columns that hold a stored image (a path inside the uploads folder).
  @image_columns [:logo_path, :signature_path]

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

  `images` is what the upload code stored: `%{logo_path: "12/ab12.png", signature_path: "12/cd34.jpg"}`,
  with either key left out when there is no such image. It is a separate argument, and not part of
  `attrs`, because `attrs` comes from the browser and the paths must not.

  ## Examples

      iex> create_business(scope, %{field: value})
      {:ok, %Business{}}

      iex> create_business(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_business(%Scope{} = scope, attrs, images \\ %{}) do
    with {:ok, business = %Business{}} <-
           %Business{}
           |> Business.changeset(attrs, scope)
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
  def update_business(%Scope{} = scope, %Business{} = business, attrs, images \\ %{}) do
    true = business.user_id == scope.user.id

    with {:ok, updated = %Business{}} <-
           business
           |> Business.changeset(attrs, scope)
           |> Business.put_images(images)
           |> Repo.update() do
      delete_replaced_images(business, updated)
      broadcast_business(scope, {:updated, updated})
      {:ok, updated}
    end
  end

  @doc """
  Removes the logo or the signature (`kind` is `:logo` or `:signature`) and deletes its file.
  """
  def remove_image(%Scope{} = scope, %Business{} = business, kind)
      when kind in [:logo, :signature] do
    true = business.user_id == scope.user.id

    with {:ok, updated = %Business{}} <-
           business
           |> Ecto.Changeset.change(%{image_column(kind) => nil})
           |> Repo.update() do
      delete_replaced_images(business, updated)
      broadcast_business(scope, {:updated, updated})
      {:ok, updated}
    end
  end

  defp image_column(:logo), do: :logo_path
  defp image_column(:signature), do: :signature_path

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

    Business.changeset(business, attrs, scope)
  end

  @doc """
  What the renderer needs to draw the logo and the signature of a business:

    * `data`, the file names to add to the document's data (`%{"logo" => "logo.png"}`), and
    * `files`, a map from each of those names to the stored file, to copy next to the template.

  An image whose file has gone missing is left out, so the document is made without it. `nil` (no business)
  has no pictures at all.
  """
  def render_assets(nil), do: %{data: %{}, files: %{}}

  def render_assets(%Business{} = business) do
    for {key, relative} <- [logo: business.logo_path, signature: business.signature_path],
        relative != nil and File.regular?(Uploads.path(relative)),
        reduce: %{data: %{}, files: %{}} do
      %{data: data, files: files} ->
        name = Atom.to_string(key) <> Path.extname(relative)

        %{
          data: Map.put(data, Atom.to_string(key), name),
          files: Map.put(files, name, Uploads.path(relative))
        }
    end
  end
end
