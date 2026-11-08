defmodule QuickSlipsWeb.StampController do
  @moduledoc """
  Saves a revenue stamp from a bill's page, without leaving the bill: `POST /api/stamps` with the `name` and the
  picture (`file`) of the stamp. A logged-in user only.

  The answer is the stamp (`%{stamp: %{id, name, url}}`), or an error with a `code` the page turns into a
  sentence in its own language (`name_blank`, `name_taken`, `name_too_long`, `limit_reached`, `unsupported_type`,
  `too_large`, `file_too_large`, `no_file`).
  """
  use QuickSlipsWeb, :controller

  alias QuickSlips.Stamps
  alias QuickSlipsWeb.UploadController

  action_fallback QuickSlipsWeb.FallbackController

  @doc "How the page (`assets/js/bill`) sees a stamp: its id, its name and the address of its picture."
  def payload(stamp) do
    %{id: stamp.id, name: stamp.name, url: UploadController.path(stamp.path)}
  end

  @doc "How the page sees a stamp the site provides: `system:<id>` as its id, its name, and where its picture is."
  def system_payload(%{id: id, name: name, file: file}),
    do: %{id: "system:" <> id, name: name, url: "/images/stamps/" <> file}

  @doc "`GET /images/stamps/:file`: the picture of a stamp the site provides (they are not under `priv/static`)."
  def system(conn, %{"file" => file}) do
    case Enum.find(QuickSlips.Stamps.system_stamps(), &(&1.file == file)) do
      nil ->
        send_resp(conn, 404, "Not found")

      %{path: path} ->
        conn
        |> put_resp_header("cache-control", "public, max-age=86400")
        |> put_resp_content_type(MIME.from_path(path))
        |> send_file(200, path)
    end
  end

  def create(conn, %{"file" => %Plug.Upload{path: path}} = params) do
    with {:ok, scope} <- fetch_scope(conn) do
      case Stamps.create_stamp(scope, %{"name" => params["name"]}, path) do
        {:ok, stamp} ->
          conn |> put_status(:created) |> json(%{stamp: payload(stamp)})

        {:error, %Ecto.Changeset{} = changeset} ->
          refuse(conn, name_error(changeset))

        {:error, reason} when is_atom(reason) ->
          refuse(conn, Atom.to_string(reason))
      end
    end
  end

  def create(conn, _params) do
    with {:ok, _scope} <- fetch_scope(conn), do: refuse(conn, "no_file")
  end

  defp fetch_scope(conn) do
    case conn.assigns[:current_scope] do
      %{user: %{}} = scope -> {:ok, scope}
      _anonymous -> {:error, :unauthorized}
    end
  end

  defp refuse(conn, code) do
    conn |> put_status(:unprocessable_entity) |> json(%{code: code})
  end

  # Which thing is wrong with the name: the changeset says it with a validation, not with a word.
  defp name_error(%Ecto.Changeset{errors: errors}) do
    case Keyword.get(errors, :name) do
      {_message, [validation: :required]} -> "name_blank"
      {_message, [count: _, validation: :length, kind: :max, type: :string]} -> "name_too_long"
      {_message, [constraint: :unique, constraint_name: _]} -> "name_taken"
      _other -> "name_blank"
    end
  end
end
