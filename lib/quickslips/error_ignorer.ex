defmodule QuickSlips.ErrorIgnorer do
  @moduledoc """
  Keeps the visitor's mistakes out of ErrorTracker: a mistyped URL, a bad request or an expired form is
  not a bug in QuickSlips.

  An exception knows its HTTP status (see `Plug.Exception`): `QuickSlipsWeb.NotFoundError` is a 404, a bad
  CSRF token a 403, a request that can't be parsed a 400. Anything below 500 is ignored.
  """
  @behaviour ErrorTracker.Ignorer

  @impl true
  def ignore?(%ErrorTracker.Error{kind: kind}, _context), do: client_error?(kind)

  # `kind` is the exception's module name as a string, or "exit", "throw" and the like for other failures.
  defp client_error?(kind) do
    module = String.to_existing_atom(kind)

    Code.ensure_loaded?(module) and function_exported?(module, :__struct__, 0) and
      Plug.Exception.status(struct(module)) < 500
  rescue
    _ -> false
  end
end
