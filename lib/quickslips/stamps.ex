defmodule QuickSlips.Stamps do
  @moduledoc """
  The revenue stamps of a user: the pictures to choose from on a receipt that has a place for one (in India a
  receipt above a sum carries a revenue stamp; the layouts draw a box for it). A receipt can also use the default
  stamp that the site provides (every picture in `priv/images/stamps`, see `system_stamps/0`), or keep the empty box
  to stick a real stamp on. A document remembers the choice, so the history can draw it again.

  It works like `QuickSlips.Signatures`, and the pictures are kept in the same way (`QuickSlips.Uploads`).
  """

  import Ecto.Query, warn: false

  alias QuickSlips.Accounts.Scope
  alias QuickSlips.Repo
  alias QuickSlips.Stamps.Stamp
  alias QuickSlips.Uploads

  # Every stamp is a file of up to 1 MB on disk, so one account may not keep an unlimited number. A person has a few.
  @max_per_user 10

  def max_per_user, do: @max_per_user

  @doc """
  Subscribes to scoped notifications about the user's stamps:

    * {:created, %Stamp{}}
    * {:deleted, %Stamp{}}
  """
  def subscribe_stamps(%Scope{} = scope) do
    Phoenix.PubSub.subscribe(QuickSlips.PubSub, "user:#{scope.user.id}:stamps")
  end

  defp broadcast_stamp(%Scope{} = scope, message) do
    Phoenix.PubSub.broadcast(QuickSlips.PubSub, "user:#{scope.user.id}:stamps", message)
  end

  @doc "The user's stamps, by name (capital letters do not count)."
  def list_stamps(%Scope{} = scope) do
    Repo.all(
      from s in Stamp,
        where: s.user_id == ^scope.user.id,
        order_by: [asc: fragment("lower(?)", s.name), asc: s.id]
    )
  end

  @doc "How many stamps the user has saved."
  def count_stamps(%Scope{} = scope) do
    Repo.aggregate(from(s in Stamp, where: s.user_id == ^scope.user.id), :count)
  end

  @doc "Gets one of the user's stamps. Raises `Ecto.NoResultsError` for one that is not there or is somebody else's."
  def get_stamp!(%Scope{} = scope, id) do
    Repo.get_by!(Stamp, id: id, user_id: scope.user.id)
  end

  @doc """
  The user's stamp with this id, or `nil` when there is none or it is somebody else's. The id may be a string, a
  number or `nil` (what a form or a saved document holds).
  """
  def get_stamp(%Scope{} = scope, id) do
    case Ecto.Type.cast(:id, id) do
      {:ok, id} when is_integer(id) -> Repo.get_by(Stamp, id: id, user_id: scope.user.id)
      _no_id -> nil
    end
  end

  @doc """
  Saves the picture in `upload_path` (the temp file of an upload) as a new stamp called `attrs.name`.

  Returns `{:ok, %Stamp{}}`, `{:error, %Ecto.Changeset{}}` (the name is missing, too long or used),
  `{:error, :limit_reached}` (the user keeps #{@max_per_user} already), or what `Uploads.store/2` refuses:
  `:unsupported_type`, `:too_large` or `:file_too_large`.
  """
  def create_stamp(%Scope{} = scope, attrs, upload_path) do
    changeset = Stamp.changeset(%Stamp{user_id: scope.user.id}, attrs)

    cond do
      not changeset.valid? ->
        {:error, %{changeset | action: :insert}}

      count_stamps(scope) >= @max_per_user ->
        {:error, :limit_reached}

      true ->
        with {:ok, relative} <- Uploads.store(scope.user.id, upload_path) do
          save_stored(scope, changeset, relative)
        end
    end
  end

  defp save_stored(scope, changeset, relative) do
    case changeset |> Ecto.Changeset.put_change(:path, relative) |> Repo.insert() do
      {:ok, stamp} ->
        broadcast_stamp(scope, {:created, stamp})
        {:ok, stamp}

      {:error, changeset} ->
        # The name was taken meanwhile: the picture has no stamp to belong to.
        Uploads.delete(relative)
        {:error, changeset}
    end
  end

  @doc "Deletes a stamp and its file. The documents that used it stay, without the picture."
  def delete_stamp(%Scope{} = scope, %Stamp{} = stamp) do
    true = stamp.user_id == scope.user.id

    with {:ok, stamp} <- Repo.delete(stamp) do
      Uploads.delete(stamp.path)
      broadcast_stamp(scope, {:deleted, stamp})
      {:ok, stamp}
    end
  end

  @doc "A changeset for the name form of a new stamp."
  def change_stamp(%Scope{} = scope, %Stamp{} = stamp, attrs \\ %{}) do
    true = stamp.user_id == scope.user.id
    Stamp.changeset(stamp, attrs)
  end

  @system_dir "images/stamps"

  @doc """
  The stamps that the site provides: every PNG or JPG in `priv/images/stamps`, by file name. Add a picture to the
  folder and it is offered on the receipts, with no other change. Each is `%{id: "india-rupee-one-revenue-stamp",
  name: "India rupee one revenue stamp", file: "india-rupee-one-revenue-stamp.jpeg", path: "/abs/path"}`.
  """
  def system_stamps do
    dir = Application.app_dir(:quickslips, Path.join("priv", @system_dir))

    for file <- File.ls!(dir) |> Enum.sort(),
        String.downcase(Path.extname(file)) in ~w(.png .jpg .jpeg) do
      id = Path.rootname(file)

      %{
        id: id,
        name: id |> String.replace(["-", "_"], " ") |> String.capitalize(),
        file: file,
        path: Path.join(dir, file)
      }
    end
  rescue
    File.Error -> []
  end

  @doc "The stamp the site provides with this id (the file name without its extension), or `nil`."
  def system_stamp(id), do: Enum.find(system_stamps(), &(&1.id == id))

  @doc """
  What the renderer needs to draw the stamp that was chosen, in the shape of `Signatures.render_assets/1`:

    * `nil`: nothing, so the layout draws the empty box;
    * `{:system, id}`: the picture the site provides under this id (nothing if there is none);
    * a saved `%Stamp{}`: its picture, `%{data: %{"stamp" => "stamp.png"}, files: %{"stamp.png" => "/abs/path"}}`. One
      whose file has gone missing gives nothing, like a signature.
  """
  def render_assets(nil), do: %{data: %{}, files: %{}}

  def render_assets({:system, id}) do
    case system_stamp(id) do
      nil ->
        %{data: %{}, files: %{}}

      %{file: file, path: path} ->
        %{
          data: %{"stamp" => "stamp" <> Path.extname(file)},
          files: %{("stamp" <> Path.extname(file)) => path}
        }
    end
  end

  def render_assets(%Stamp{path: relative}) do
    if File.regular?(Uploads.path(relative)) do
      name = "stamp" <> Path.extname(relative)
      %{data: %{"stamp" => name}, files: %{name => Uploads.path(relative)}}
    else
      %{data: %{}, files: %{}}
    end
  end
end
