defmodule QuickSlipsWeb.UploadController do
  @moduledoc """
  Serves the images users uploaded (logo, signature). They are not under `priv/static`, so nobody
  can reach them without going through here, and only the owner gets them.
  """
  use QuickSlipsWeb, :controller

  alias QuickSlips.Uploads

  @content_types %{".png" => "image/png", ".jpg" => "image/jpeg"}

  @doc """
  The URL of a stored image, for `<img src>`. `relative` is the stored path, like `"12/a1b2c3d4e5f60718.png"`.
  The route has two segments, so the path is split here instead of being encoded as one.
  """
  def path(nil), do: nil

  def path(relative) do
    [user_id, file] = String.split(relative, "/")
    ~p"/uploads/#{user_id}/#{file}"
  end

  def show(conn, %{"user_id" => user_id, "file" => file}) do
    owner? = Integer.to_string(conn.assigns.current_scope.user.id) == user_id

    # The name is a random 16-character hex string and one of two extensions: nothing else gets in.
    safe? = Regex.match?(~r/^[a-f0-9]{16}\.(png|jpg)$/, file)
    path = if owner? and safe?, do: Uploads.path(Path.join(user_id, file))

    if path && File.regular?(path) do
      conn
      |> put_resp_content_type(Map.fetch!(@content_types, Path.extname(file)), nil)
      # The name changes whenever the image does, so the browser may keep its copy.
      |> put_resp_header("cache-control", "private, max-age=86400")
      |> send_file(200, path)
    else
      raise QuickSlipsWeb.NotFoundError
    end
  end
end
