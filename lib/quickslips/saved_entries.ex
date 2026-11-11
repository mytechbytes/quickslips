defmodule QuickSlips.SavedEntries do
  @moduledoc """
  The details of one section of a bill's form that a user keeps to fill it again: the employees of a salary receipt,
  its drivers. A section that may be saved is named in the `saved_groups` of the bill's schema. The entries belong
  to the bill and the section (`"driver-salary-receipt/customer"`), so the list of drivers holds drivers only.

  An entry is made new or updated by its id (`save_entry/5`); a name is the user's own once in a section.
  """

  import Ecto.Query, warn: false

  alias QuickSlips.Accounts.Scope
  alias QuickSlips.Repo
  alias QuickSlips.SavedEntries.SavedEntry

  # One person keeps a few of each kind; the limit stops a flood.
  @max_per_key 50

  def max_per_key, do: @max_per_key

  @doc "The user's entries of a bill, as `%{\"customer\" => [%{id, name, data}]}` (a section that has none is not there)."
  def list_entries(%Scope{} = scope, slug) do
    Repo.all(
      from e in SavedEntry,
        where: e.user_id == ^scope.user.id and like(e.key, ^"#{slug}/%"),
        order_by: fragment("lower(?)", e.name)
    )
    |> Enum.group_by(&group_of(&1.key), &payload/1)
  end

  def payload(entry), do: %{id: entry.id, name: entry.name, data: entry.data}

  defp group_of(key), do: key |> String.split("/", parts: 2) |> List.last()

  @doc """
  Keeps `data` under `name` for the section `key`. With the `id` of an entry of the user it updates that entry (and
  may rename it); without one it makes a new entry. Returns `{:ok, entry, :created | :updated}`, or
  `{:error, :name_taken | :not_found | :limit_reached}`: a name is the user's own once in a section, capitals
  not counting.
  """
  def save_entry(%Scope{} = scope, key, name, data, id \\ nil) do
    taken = by_name(scope, key, name)

    cond do
      id == nil and taken != nil ->
        {:error, :name_taken}

      id == nil and count(scope, key) >= @max_per_key ->
        {:error, :limit_reached}

      id == nil ->
        {:ok, entry} =
          Repo.insert(%SavedEntry{user_id: scope.user.id, key: key, name: name, data: data})

        {:ok, entry, :created}

      true ->
        case Repo.get_by(SavedEntry, id: id, user_id: scope.user.id, key: key) do
          nil ->
            {:error, :not_found}

          %{id: own} when taken != nil and taken.id != own ->
            {:error, :name_taken}

          entry ->
            {:ok, entry} = entry |> Ecto.Changeset.change(name: name, data: data) |> Repo.update()
            {:ok, entry, :updated}
        end
    end
  end

  defp by_name(scope, key, name) do
    lowered = String.downcase(name)

    Repo.one(
      from e in SavedEntry,
        where:
          e.user_id == ^scope.user.id and e.key == ^key and
            fragment("lower(?)", e.name) == ^lowered
    )
  end

  defp count(scope, key),
    do:
      Repo.aggregate(
        from(e in SavedEntry, where: e.user_id == ^scope.user.id and e.key == ^key),
        :count
      )
end
