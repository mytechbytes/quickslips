defmodule QuickSlips.Businesses do
  @moduledoc """
  The Businesses context.
  """

  import Ecto.Query, warn: false
  alias QuickSlips.Repo

  alias QuickSlips.Businesses.Business
  alias QuickSlips.Accounts.Scope

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

  ## Examples

      iex> create_business(scope, %{field: value})
      {:ok, %Business{}}

      iex> create_business(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_business(%Scope{} = scope, attrs) do
    with {:ok, business = %Business{}} <-
           %Business{}
           |> Business.changeset(attrs, scope)
           |> Repo.insert() do
      broadcast_business(scope, {:created, business})
      {:ok, business}
    end
  end

  @doc """
  Updates a business.

  ## Examples

      iex> update_business(scope, business, %{field: new_value})
      {:ok, %Business{}}

      iex> update_business(scope, business, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_business(%Scope{} = scope, %Business{} = business, attrs) do
    true = business.user_id == scope.user.id

    with {:ok, business = %Business{}} <-
           business
           |> Business.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_business(scope, {:updated, business})
      {:ok, business}
    end
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
end
