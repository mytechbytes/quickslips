defmodule QuickSlipsWeb.TemplateSourceController do
  use QuickSlipsWeb, :controller

  alias QuickSlips.Templates

  def show(conn, %{"slug" => slug, "template" => template}) do
    with {:ok, %{"templates" => designs}} <- Templates.get(slug),
         true <- Enum.any?(designs, &(&1["id"] == template)) do
      conn
      |> put_resp_content_type("text/plain")
      |> put_resp_header("cache-control", "public, max-age=300")
      |> send_file(200, Path.join(Templates.template_dir(slug), template <> ".typ"))
    else
      _ -> raise QuickSlipsWeb.NotFoundError
    end
  end
end
