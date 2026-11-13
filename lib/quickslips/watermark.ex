defmodule QuickSlips.Watermark do
  @moduledoc """
  The watermark a user may put on a document (the "Watermark" part of the advanced settings): a text or a picture, put
  `count` times on every page in a `layout`, each turned by `angle` degrees.

  The settings come from the page as a map:

      %{"type" => "text", "text" => "PAID", "layout" => "diagonal", "angle" => 30, "count" => 3}
      %{"type" => "image", "image_data" => "data:image/png;base64,...", "layout" => "grid", "angle" => 0, "count" => 12}

  `prepare/1` checks them and says what the render needs: the settings for the data of the template (under
  `"watermark"`, which the helpers read) and the picture, as bytes, for the files of the render. `settings/1` is what is
  kept with a document in the history: the same without the picture, which is too big to keep and has to be chosen again.
  """

  @layouts ~w(diagonal horizontal vertical grid)
  @max_text 40
  @max_count 50
  @max_image_bytes 1_500_000
  @png <<137, 80, 78, 71, 13, 10, 26, 10>>

  @doc "The layouts a user may choose."
  def layouts, do: @layouts

  @doc """
  The checked settings of a watermark without its picture, or `nil` for no watermark (nothing chosen, an empty text,
  something that is not a map). A text is cut to #{@max_text} characters, an angle to a turn each way, a count to
  1 to #{@max_count}.
  """
  def settings(%{"type" => "text"} = params) do
    case params["text"] |> to_string() |> String.trim() |> String.slice(0, @max_text) do
      "" -> nil
      text -> params |> common() |> Map.merge(%{"type" => "text", "text" => text})
    end
  end

  def settings(%{"type" => "image"} = params),
    do: params |> common() |> Map.put("type", "image")

  def settings(_none), do: nil

  defp common(params) do
    layout = if params["layout"] in @layouts, do: params["layout"], else: "diagonal"

    %{
      "layout" => layout,
      "angle" => angle(params["angle"], layout),
      "count" => count(params["count"])
    }
  end

  defp angle(value, layout) do
    case number(value) do
      nil -> default_angle(layout)
      angle -> angle |> max(-360) |> min(360)
    end
  end

  defp default_angle("diagonal"), do: 45
  defp default_angle("vertical"), do: 90
  defp default_angle(_layout), do: 0

  defp count(value) do
    case number(value) do
      nil -> 1
      count -> count |> round() |> max(1) |> min(@max_count)
    end
  end

  defp number(value) when is_number(value), do: value

  defp number(value) when is_binary(value) do
    case Float.parse(value) do
      {number, ""} -> number
      _ -> nil
    end
  end

  defp number(_value), do: nil

  @doc """
  What the render needs: `{:ok, %{data: data, files: files}}` (with `data` empty when there is no watermark), or
  `{:error, :bad_request}` for a picture that is too big or is not a PNG or a JPEG.
  """
  def prepare(params) when is_map(params) do
    case settings(params) do
      nil -> {:ok, %{data: %{}, files: %{}}}
      %{"type" => "text"} = settings -> {:ok, %{data: %{"watermark" => settings}, files: %{}}}
      %{"type" => "image"} = settings -> with_image(settings, params["image_data"])
    end
  end

  def prepare(_none), do: {:ok, %{data: %{}, files: %{}}}

  # A watermark that is a picture with no picture (a document made again from the history) is left out.
  defp with_image(_settings, data) when data in [nil, ""], do: {:ok, %{data: %{}, files: %{}}}

  defp with_image(settings, "data:" <> rest) do
    with [_type, encoded] <- String.split(rest, ";base64,", parts: 2),
         {:ok, bytes} <- Base.decode64(encoded),
         true <- byte_size(bytes) <= @max_image_bytes,
         {:ok, ext} <- extension(bytes) do
      name = "watermark." <> ext

      {:ok,
       %{
         data: %{"watermark" => Map.put(settings, "image", name)},
         files: %{name => {:binary, bytes}}
       }}
    else
      _ -> {:error, :bad_request}
    end
  end

  defp with_image(_settings, _other), do: {:error, :bad_request}

  defp extension(<<@png, _::binary>>), do: {:ok, "png"}
  defp extension(<<0xFF, 0xD8, 0xFF, _::binary>>), do: {:ok, "jpg"}
  defp extension(_bytes), do: :error
end
