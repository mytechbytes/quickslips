defmodule QuickSlipsWeb.SavedEntryController do
  @moduledoc """
  Saves the details of one section of a bill's form (the employee, the driver, the vehicle) from the bill's page:
  `POST /api/saved-entries` with the bill's `slug`, the `group` (the section) and the `data` (the value of each field
  of it). A logged-in user only. The section has to be one that the bill lets be saved (`saved_groups` of its
  schema); only the fields of that section are kept, cut to their length.

  With the `id` of a saved entry that entry is updated; without one a new entry is made. The name that the picker
  shows is the first required field of the section, or, in a section that has none, its first field that is filled in.
  The answer is the entry and what happened (`%{entry: %{id, name, data}, outcome: "created" | "updated"}`), or
  status 422 with a `code`: `name_blank`, `name_taken` (a new entry with a name that is saved), `not_found` (an `id` that
  is not the user's), `limit_reached`, or `not_saved` (a section that may not be saved).
  """
  use QuickSlipsWeb, :controller

  alias QuickSlips.SavedEntries
  alias QuickSlips.Templates

  action_fallback QuickSlipsWeb.FallbackController

  def create(conn, %{"slug" => slug, "group" => group, "data" => data} = params)
      when is_map(data) do
    with {:ok, scope} <- fetch_scope(conn),
         {:ok, schema} <- Templates.get(slug),
         true <- group in (schema["saved_groups"] || []) or {:error, :not_saved} do
      fields =
        Enum.filter(
          schema["fields"],
          &(&1["group"] == group and &1["type"] in ["text", "textarea", "select"])
        )

      kept = keep(fields, data)
      name = name_of(fields, kept)

      if name == "" do
        refuse(conn, "name_blank")
      else
        case SavedEntries.save_entry(scope, "#{slug}/#{group}", name, kept, params["id"]) do
          {:ok, entry, outcome} ->
            json(conn, %{entry: SavedEntries.payload(entry), outcome: outcome})

          {:error, code} ->
            refuse(conn, Atom.to_string(code))
        end
      end
    else
      {:error, :not_saved} -> refuse(conn, "not_saved")
      {:error, :not_found} -> refuse(conn, "not_saved")
      {:error, :unauthorized} = error -> error
    end
  end

  def create(conn, _params), do: refuse(conn, "name_blank")

  defp keep(fields, data) do
    for field <- fields,
        value = data[field["key"]],
        is_binary(value),
        String.trim(value) != "",
        into: %{} do
      {field["key"], value |> String.trim() |> String.slice(0, field["max_length"] || 200)}
    end
  end

  defp name_of(fields, kept) do
    fields
    |> Enum.sort_by(&(&1["required"] != true))
    |> Enum.find_value("", &Map.get(kept, &1["key"]))
  end

  defp refuse(conn, code), do: conn |> put_status(:unprocessable_entity) |> json(%{code: code})

  defp fetch_scope(conn) do
    case conn.assigns[:current_scope] do
      %{user: %{}} = scope -> {:ok, scope}
      _anonymous -> {:error, :unauthorized}
    end
  end
end
