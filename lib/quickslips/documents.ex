defmodule QuickSlips.Documents do
  @moduledoc """
  The Documents context.
  """

  import Ecto.Query, warn: false
  alias QuickSlips.Repo

  alias QuickSlips.Documents.Document
  alias QuickSlips.Accounts.Scope

  # Nobody needs more in their history than this, and it keeps one account from filling the database.
  # When a new document goes over the limit, the oldest ones are deleted.
  @max_per_user 200

  @doc """
  Subscribes to scoped notifications about any document changes.

  The broadcasted messages match the pattern:

    * {:created, %Document{}}
    * {:updated, %Document{}}
    * {:deleted, %Document{}}

  """
  def subscribe_documents(%Scope{} = scope) do
    key = scope.user.id

    Phoenix.PubSub.subscribe(QuickSlips.PubSub, "user:#{key}:documents")
  end

  defp broadcast_document(%Scope{} = scope, message) do
    key = scope.user.id

    Phoenix.PubSub.broadcast(QuickSlips.PubSub, "user:#{key}:documents", message)
  end

  @doc """
  Returns the user's documents, newest first.

  Options: `search: "fuel"` keeps only the documents whose title contains the text, and `limit: n`.

  ## Examples

      iex> list_documents(scope)
      [%Document{}, ...]

  """
  def list_documents(%Scope{} = scope, opts \\ []) do
    Document
    |> where(user_id: ^scope.user.id)
    |> search(Keyword.get(opts, :search))
    |> order_by([d], desc: d.inserted_at, desc: d.id)
    |> limit(^Keyword.get(opts, :limit, @max_per_user))
    |> Repo.all()
  end

  defp search(query, term) when term in [nil, ""], do: query

  defp search(query, term) do
    # `%` and `_` are wildcards in LIKE, so a user who types one means the character itself.
    escaped = term |> String.trim() |> String.replace(~r/[\\%_]/, "\\\\\\0")
    where(query, [d], ilike(d.title, ^"%#{escaped}%"))
  end

  @doc "How many documents the user made since the first of this month (UTC)."
  def count_this_month(%Scope{} = scope) do
    first_of_month = Date.beginning_of_month(Date.utc_today())
    from_time = DateTime.new!(first_of_month, ~T[00:00:00], "Etc/UTC")

    Repo.aggregate(
      from(d in Document, where: d.user_id == ^scope.user.id and d.inserted_at >= ^from_time),
      :count
    )
  end

  @doc """
  Gets a single document.

  Raises `Ecto.NoResultsError` if the Document does not exist.

  ## Examples

      iex> get_document!(scope, 123)
      %Document{}

      iex> get_document!(scope, 456)
      ** (Ecto.NoResultsError)

  """
  def get_document!(%Scope{} = scope, id) do
    Repo.get_by!(Document, id: id, user_id: scope.user.id)
  end

  @doc """
  The document of the user with this id, made with the template `slug`, or `nil`. It prefills the form of
  "edit and regenerate", so a missing or foreign document just means the form starts empty.
  """
  def get_document_for_template(%Scope{} = scope, id, slug) do
    case Ecto.Type.cast(:id, id) do
      {:ok, id} when is_integer(id) ->
        Repo.get_by(Document, id: id, user_id: scope.user.id, slug: slug)

      _no_id ->
        nil
    end
  end

  @doc """
  Creates a document. `business` is the saved business whose logo and signature were drawn on it, or `nil`.

  ## Examples

      iex> create_document(scope, %{field: value})
      {:ok, %Document{}}

      iex> create_document(scope, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_document(%Scope{} = scope, attrs, business \\ nil) do
    with {:ok, document = %Document{}} <-
           %Document{}
           |> Document.changeset(attrs, scope)
           |> Document.put_business(business)
           |> Repo.insert() do
      delete_oldest(scope)
      broadcast_document(scope, {:created, document})
      {:ok, document}
    end
  end

  defp delete_oldest(%Scope{} = scope) do
    keep =
      from d in Document,
        where: d.user_id == ^scope.user.id,
        order_by: [desc: d.inserted_at, desc: d.id],
        limit: @max_per_user,
        select: d.id

    Repo.delete_all(
      from d in Document, where: d.user_id == ^scope.user.id and d.id not in subquery(keep)
    )
  end

  @doc """
  A title for the history list, like `"Fuel Bill · FB-10482 · Sunrise Fuel Station · 12 Oct 2026"`: the name of
  the template, the document's number (the field the schema names in `"number_field"`), the seller (the
  field that is filled from a saved business's name) and the first date. What the data does not have is left out.
  """
  def build_title(schema, data) do
    fields = schema["fields"]
    number = present(data[schema["number_field"]])

    seller =
      Enum.find_value(fields, fn field ->
        field["prefill"] == "business.name" && present(data[field["key"]])
      end)

    date = first_value(fields, data, "date") || first_value(fields, data, "month")
    name = String.replace_suffix(schema["title"], " Generator", "")

    [name, number, seller, date && format_date(date)]
    |> Enum.reject(&(&1 in [nil, false]))
    |> Enum.join(" · ")
  end

  defp present(value) when is_binary(value) and value != "", do: value
  defp present(_value), do: nil

  # The value of the first field of this type that has one.
  defp first_value(fields, data, type) do
    Enum.find_value(fields, fn field -> field["type"] == type && present(data[field["key"]]) end)
  end

  # "2026-10-12" -> "12 Oct 2026", "2026-10" -> "Oct 2026". Anything else is shown as it is.
  defp format_date(<<_::binary-size(7)>> = month) do
    case Date.from_iso8601(month <> "-01") do
      {:ok, date} -> Calendar.strftime(date, "%b %Y")
      _ -> month
    end
  end

  defp format_date(value) do
    case Date.from_iso8601(value) do
      {:ok, date} -> Calendar.strftime(date, "%d %b %Y")
      _ -> value
    end
  end

  @doc """
  Updates a document.

  ## Examples

      iex> update_document(scope, document, %{field: new_value})
      {:ok, %Document{}}

      iex> update_document(scope, document, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_document(%Scope{} = scope, %Document{} = document, attrs) do
    true = document.user_id == scope.user.id

    with {:ok, document = %Document{}} <-
           document
           |> Document.changeset(attrs, scope)
           |> Repo.update() do
      broadcast_document(scope, {:updated, document})
      {:ok, document}
    end
  end

  @doc """
  Deletes a document.

  ## Examples

      iex> delete_document(scope, document)
      {:ok, %Document{}}

      iex> delete_document(scope, document)
      {:error, %Ecto.Changeset{}}

  """
  def delete_document(%Scope{} = scope, %Document{} = document) do
    true = document.user_id == scope.user.id

    with {:ok, document = %Document{}} <-
           Repo.delete(document) do
      broadcast_document(scope, {:deleted, document})
      {:ok, document}
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking document changes.

  ## Examples

      iex> change_document(scope, document)
      %Ecto.Changeset{data: %Document{}}

  """
  def change_document(%Scope{} = scope, %Document{} = document, attrs \\ %{}) do
    true = document.user_id == scope.user.id

    Document.changeset(document, attrs, scope)
  end
end
