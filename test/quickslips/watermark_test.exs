defmodule QuickSlips.WatermarkTest do
  use ExUnit.Case, async: true

  alias QuickSlips.Watermark

  @png <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 0>>

  defp data_url(bytes, type \\ "image/png"), do: "data:#{type};base64," <> Base.encode64(bytes)

  test "no settings, no type and an empty text are no watermark" do
    assert {:ok, %{data: data, files: files}} = Watermark.prepare(nil)
    assert data == %{} and files == %{}
    assert {:ok, %{data: %{}}} = Watermark.prepare(%{})
    assert {:ok, %{data: %{}}} = Watermark.prepare(%{"type" => "text", "text" => "   "})
  end

  test "a text is trimmed and cut, the layout, angle and count are checked" do
    assert {:ok, %{data: %{"watermark" => mark}}} =
             Watermark.prepare(%{
               "type" => "text",
               "text" => "  " <> String.duplicate("A", 60),
               "layout" => "spiral",
               "angle" => "999",
               "count" => 500
             })

    assert mark == %{
             "type" => "text",
             "text" => String.duplicate("A", 40),
             "layout" => "diagonal",
             "angle" => 360,
             "count" => 50
           }
  end

  test "the angle of a layout starts at its own, and the count at 1" do
    assert %{"angle" => 90, "count" => 1} =
             Watermark.settings(%{"type" => "text", "text" => "X", "layout" => "vertical"})

    assert %{"angle" => 0} =
             Watermark.settings(%{"type" => "text", "text" => "X", "layout" => "horizontal"})
  end

  test "a picture goes to the files as bytes, by the name the data gives it" do
    assert {:ok, %{data: %{"watermark" => mark}, files: files}} =
             Watermark.prepare(%{
               "type" => "image",
               "image_data" => data_url(@png),
               "layout" => "grid",
               "angle" => 0,
               "count" => 6
             })

    assert mark["image"] == "watermark.png"
    assert files == %{"watermark.png" => {:binary, @png}}
  end

  test "a picture that is not a PNG or a JPEG, or is too big, is turned down" do
    base = %{"type" => "image", "layout" => "grid"}

    assert {:error, :bad_request} =
             Watermark.prepare(
               Map.put(base, "image_data", data_url("<svg></svg>", "image/svg+xml"))
             )

    assert {:error, :bad_request} =
             Watermark.prepare(
               Map.put(base, "image_data", data_url(@png <> :binary.copy(<<0>>, 1_600_000)))
             )

    assert {:error, :bad_request} = Watermark.prepare(Map.put(base, "image_data", "nonsense"))
  end

  test "a picture watermark with no picture (made again from the history) is left out" do
    assert {:ok, %{data: %{}, files: %{}}} = Watermark.prepare(%{"type" => "image"})
  end

  test "what the history keeps has no picture" do
    assert %{"type" => "image"} =
             settings = Watermark.settings(%{"type" => "image", "image_data" => "x"})

    refute Map.has_key?(settings, "image_data")
  end

  describe "on a page" do
    @describetag :typst

    alias QuickSlips.Render.Renderer

    defp sample,
      do: "priv/bill_templates/fuel-bill/sample.json" |> File.read!() |> Jason.decode!()

    test "every layout compiles, in the PDF and in the preview with the mark of QuickSlips" do
      for layout <- Watermark.layouts(), mode <- [:final, :preview], paper <- [nil, "a4"] do
        mark = %{
          "type" => "text",
          "text" => "PAID",
          "layout" => layout,
          "angle" => 45,
          "count" => 4
        }

        data =
          sample()
          |> Map.put("watermark", mark)
          |> then(&if paper, do: Map.put(&1, "paper_size", paper), else: &1)

        assert {:ok, "%PDF" <> _} = Renderer.render("fuel-bill", "t1", data, mode: mode),
               "#{layout} #{mode} #{paper}"
      end
    end
  end
end
