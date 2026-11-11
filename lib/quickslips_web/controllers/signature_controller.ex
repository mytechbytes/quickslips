defmodule QuickSlipsWeb.SignatureController do
  @moduledoc """
  Saves a signature from a bill's page, without leaving the bill: `POST /api/signatures` with the `name` and the
  picture (`file`) of the signature. A logged-in user only.

  The answer is the signature (`%{signature: %{id, name, url}}`), or an error with a `code` the page turns into a
  sentence in its own language (`name_blank`, `name_taken`, `name_too_long`, `limit_reached`, `unsupported_type`,
  `too_large`, `file_too_large`, `no_file`, `rights_not_confirmed`).
  """
  use QuickSlipsWeb, :controller

  alias QuickSlips.Signatures
  alias QuickSlipsWeb.UploadController

  action_fallback QuickSlipsWeb.FallbackController

  @doc "How the page (`assets/js/bill`) sees a signature: its id, its name and the address of its picture."
  def payload(signature) do
    %{id: signature.id, name: signature.name, url: UploadController.path(signature.path)}
  end

  # A picture is kept only when the user says it is theirs to use (`rights=true`).
  def create(conn, %{"file" => %Plug.Upload{path: path}, "rights" => "true"} = params) do
    with {:ok, scope} <- fetch_scope(conn) do
      case Signatures.create_signature(scope, %{"name" => params["name"]}, path) do
        {:ok, signature} ->
          conn |> put_status(:created) |> json(%{signature: payload(signature)})

        {:error, %Ecto.Changeset{} = changeset} ->
          refuse(conn, name_error(changeset))

        {:error, reason} when is_atom(reason) ->
          refuse(conn, Atom.to_string(reason))
      end
    end
  end

  def create(conn, %{"file" => %Plug.Upload{}}) do
    with {:ok, _scope} <- fetch_scope(conn), do: refuse(conn, "rights_not_confirmed")
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
