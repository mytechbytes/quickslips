defmodule QuickSlipsWeb.FallbackController do
  use QuickSlipsWeb, :controller

  def call(conn, {:error, :bad_request}) do
    conn |> put_status(:bad_request) |> json(%{error: "expected slug, template and data"})
  end

  def call(conn, {:error, reason}) when reason in [:not_found, :unknown_template] do
    conn |> put_status(:not_found) |> json(%{error: "unknown template"})
  end

  def call(conn, {:error, {:validation, errors}}) do
    conn |> put_status(:unprocessable_entity) |> json(%{errors: errors})
  end

  def call(conn, {:error, _reason}) do
    conn
    |> put_status(:internal_server_error)
    |> json(%{error: "could not generate the document"})
  end
end
