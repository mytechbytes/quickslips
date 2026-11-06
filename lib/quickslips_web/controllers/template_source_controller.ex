defmodule QuickSlipsWeb.TemplateSourceController do
  @moduledoc """
  Serves the Typst source of a template to the browser, which compiles the preview itself (Task 6.2).
  """
  use QuickSlipsWeb, :controller

  alias QuickSlips.Templates

  # The helpers every template imports. The preview needs them next to `main.typ`, as the server has them.
  def show(conn, %{"slug" => "_shared", "template" => "helpers"}) do
    send_source(conn, Path.join([Templates.root_dir(), "_shared", "helpers.typ"]))
  end

  def show(conn, %{"slug" => slug, "template" => template}) do
    with {:ok, %{"templates" => designs}} <- Templates.get(slug),
         true <- Enum.any?(designs, &(&1["id"] == template)) do
      send_source(conn, Path.join(Templates.template_dir(slug), template <> ".typ"))
    else
      _ -> raise QuickSlipsWeb.NotFoundError
    end
  end

  defp send_source(conn, path) do
    conn
    |> put_resp_content_type("text/plain")
    |> put_resp_header("cache-control", "public, max-age=300")
    |> send_file(200, path)
  end
end
