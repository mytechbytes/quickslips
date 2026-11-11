defmodule QuickSlipsWeb.ThumbnailController do
  @moduledoc """
  `GET /thumbnails/:slug/:design`: a small picture of one design of a bill, drawn from its sample, for the design picker
  on the bill's page. Typst draws it (as a PNG of the first page) the first time it is asked for; the picture is kept
  in a folder of the machine, under a name that has a hash of the layout, the helpers and the sample in it, so a
  deploy that changes any of them draws it again and nothing else does.

  It is the same for everybody and sets no cookie (the route has no pipeline), so a browser and a proxy may keep it for
  a day. Only the bills and designs that exist can be asked for; anything else is a 404.
  """
  use QuickSlipsWeb, :controller

  alias QuickSlips.Render.Renderer
  alias QuickSlips.Templates

  def show(conn, %{"slug" => slug, "design" => design}) do
    with {:ok, schema} <- Templates.get(slug),
         true <- Enum.any?(schema["templates"], &(&1["id"] == design)),
         {:ok, png} <- thumbnail(slug, design) do
      conn
      |> put_resp_header("cache-control", "public, max-age=86400")
      |> put_resp_content_type("image/png")
      |> send_resp(200, png)
    else
      _not_found_or_failed -> send_resp(conn, 404, "Not found")
    end
  end

  defp thumbnail(slug, design) do
    file = Path.join(cache_dir(), "#{slug}-#{design}-#{fingerprint(slug, design)}.png")

    case File.read(file) do
      {:ok, png} ->
        {:ok, png}

      {:error, _not_there} ->
        with {:ok, sample} <- Templates.sample(slug),
             {:ok, png} <-
               Renderer.render(slug, design, sample, format: :png, locale: "en-in", country: "in") do
          File.mkdir_p!(cache_dir())
          File.write!(file, png)
          {:ok, png}
        end
    end
  end

  # What the picture is made of: change one and the name changes.
  defp fingerprint(slug, design) do
    dir = Templates.template_dir(slug)

    [
      Path.join(dir, design <> ".typ"),
      Path.join(dir, "sample.json"),
      Path.join([Templates.root_dir(), "_shared", "helpers.typ"])
    ]
    |> Enum.map(&File.read!/1)
    |> then(&:crypto.hash(:md5, &1))
    |> Base.encode16(case: :lower)
    |> binary_part(0, 12)
  end

  defp cache_dir, do: Path.join(System.tmp_dir!(), "quickslips-thumbnails")
end
