defmodule QuickSlips.Signatures do
  @moduledoc """
  The Signatures context: the pictures of a signature a user keeps, to choose one on a bill that has a
  signature area. A business may point at one as its default (`Businesses`), and a document points at the one that
  was drawn on it, so the history can draw it again.
  """

  import Ecto.Query, warn: false

  alias QuickSlips.Accounts.Scope
  alias QuickSlips.Repo
  alias QuickSlips.Signatures.Signature
  alias QuickSlips.Uploads

  # Every signature is a file of up to 1 MB on disk, so one account may not keep an unlimited number.
  @max_per_user 20

  def max_per_user, do: @max_per_user

  @doc """
  Subscribes to scoped notifications about the user's signatures:

    * {:created, %Signature{}}
    * {:deleted, %Signature{}}
  """
  def subscribe_signatures(%Scope{} = scope) do
    Phoenix.PubSub.subscribe(QuickSlips.PubSub, "user:#{scope.user.id}:signatures")
  end

  defp broadcast_signature(%Scope{} = scope, message) do
    Phoenix.PubSub.broadcast(QuickSlips.PubSub, "user:#{scope.user.id}:signatures", message)
  end

  @doc "The user's signatures, by name (capital letters do not count)."
  def list_signatures(%Scope{} = scope) do
    Repo.all(
      from s in Signature,
        where: s.user_id == ^scope.user.id,
        order_by: [asc: fragment("lower(?)", s.name), asc: s.id]
    )
  end

  @doc "How many signatures the user has saved."
  def count_signatures(%Scope{} = scope) do
    Repo.aggregate(from(s in Signature, where: s.user_id == ^scope.user.id), :count)
  end

  @doc """
  Gets one of the user's signatures. Raises `Ecto.NoResultsError` for a signature that does not exist or belongs to
  somebody else, which is a 404 on a page.
  """
  def get_signature!(%Scope{} = scope, id) do
    Repo.get_by!(Signature, id: id, user_id: scope.user.id)
  end

  @doc """
  The user's signature with this id, or `nil` when there is none or it is somebody else's. The id may be a
  string, a number or `nil` (what a form or a saved document holds).
  """
  def get_signature(%Scope{} = scope, id) do
    case Ecto.Type.cast(:id, id) do
      {:ok, id} when is_integer(id) -> Repo.get_by(Signature, id: id, user_id: scope.user.id)
      _no_id -> nil
    end
  end

  @doc "Whether the signature with this id is one of the user's."
  def owned?(%Scope{} = scope, id), do: get_signature(scope, id) != nil

  @doc """
  Saves the picture in `upload_path` (the temp file of an upload) as a new signature called `attrs.name`.

  Returns

    * `{:ok, %Signature{}}`,
    * `{:error, %Ecto.Changeset{}}` when the name is missing, too long or already used,
    * `{:error, :limit_reached}` when the user already keeps #{@max_per_user},
    * `{:error, :unsupported_type}` when the file is not a whole PNG or JPEG,
    * `{:error, :too_large}` when it has more pixels on a side than `Uploads` allows, and
    * `{:error, :file_too_large}` when the file is over `Uploads.max_file_size/0` bytes.

  The file is stored only when the name is fine, and it is deleted again if the signature could not be saved.
  """
  def create_signature(%Scope{} = scope, attrs, upload_path) do
    changeset = Signature.changeset(%Signature{user_id: scope.user.id}, attrs)

    cond do
      not changeset.valid? ->
        {:error, %{changeset | action: :insert}}

      count_signatures(scope) >= @max_per_user ->
        {:error, :limit_reached}

      true ->
        with {:ok, relative} <- Uploads.store(scope.user.id, upload_path) do
          save_stored(scope, changeset, relative)
        end
    end
  end

  defp save_stored(scope, changeset, relative) do
    case changeset |> Ecto.Changeset.put_change(:path, relative) |> Repo.insert() do
      {:ok, signature} ->
        broadcast_signature(scope, {:created, signature})
        {:ok, signature}

      {:error, changeset} ->
        # The name was taken meanwhile: the picture has no signature to belong to.
        Uploads.delete(relative)
        {:error, changeset}
    end
  end

  @doc """
  Deletes a signature and its file. The businesses and documents that used it stay, without the picture (the
  database does that: `on_delete: :nilify_all`).
  """
  def delete_signature(%Scope{} = scope, %Signature{} = signature) do
    true = signature.user_id == scope.user.id

    with {:ok, signature} <- Repo.delete(signature) do
      Uploads.delete(signature.path)
      broadcast_signature(scope, {:deleted, signature})
      {:ok, signature}
    end
  end

  @doc "A changeset for the name form of a new signature."
  def change_signature(%Scope{} = scope, %Signature{} = signature, attrs \\ %{}) do
    true = signature.user_id == scope.user.id
    Signature.changeset(signature, attrs)
  end

  @doc """
  What the renderer needs to draw a signature, in the shape of `Businesses.render_assets/2`:
  `%{data: %{"signature" => "signature.png"}, files: %{"signature.png" => "/abs/path"}}`. A signature whose file has
  gone missing, or none at all, gives nothing, so the document is made with the empty place to sign by hand.
  """
  def render_assets(nil), do: %{data: %{}, files: %{}}

  def render_assets(%Signature{path: relative}) do
    if File.regular?(Uploads.path(relative)) do
      name = "signature" <> Path.extname(relative)
      %{data: %{"signature" => name}, files: %{name => Uploads.path(relative)}}
    else
      %{data: %{}, files: %{}}
    end
  end
end
