defmodule QuickSlips.ErrorIgnorerTest do
  use ExUnit.Case, async: true

  alias QuickSlips.ErrorIgnorer

  defp error(kind), do: %ErrorTracker.Error{kind: to_string(kind)}

  test "a missing page, a bad request and a bad CSRF token are not bugs" do
    for kind <- [
          QuickSlipsWeb.NotFoundError,
          Phoenix.Router.NoRouteError,
          Plug.Parsers.ParseError,
          Plug.CSRFProtection.InvalidCSRFTokenError
        ] do
      assert ErrorIgnorer.ignore?(error(kind), %{}), "#{inspect(kind)} should be ignored"
    end
  end

  test "real failures are kept" do
    for kind <- [
          RuntimeError,
          ArgumentError,
          Postgrex.Error,
          "exit",
          "throw",
          "Elixir.NoSuchModule"
        ] do
      refute ErrorIgnorer.ignore?(error(kind), %{}), "#{inspect(kind)} should be kept"
    end
  end
end
