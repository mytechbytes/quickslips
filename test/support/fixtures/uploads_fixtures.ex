defmodule QuickSlips.UploadsFixtures do
  @moduledoc """
  Tiny pictures and helpers for the tests of the upload code. The test uploads folder is set in
  `config/test.exs`.
  """

  alias QuickSlips.Uploads

  # An 8x8 PNG, and an 8x8 JPEG that has an Exif segment before its picture data, like a phone's photo.
  @png [
    "iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAAM0lEQVR42mP4//+/nMN6TMQAxFjl",
    "GCAUphwDnIUmx4DMQZZjQDMBLseAaS1EjgGrW4FyADXwUsHbk39EAAAAAElFTkSuQmCC"
  ]
  @jpg [
    "/9j/4AAQSkZJRgABAQAASABIAAD/4QBMRXhpZgAATU0AKgAAAAgAAYdpAAQAAAABAAAAGgAAAAAA",
    "A6ABAAMAAAABAAEAAKACAAQAAAABAAAACKADAAQAAAABAAAACAAAAAD/7QA4UGhvdG9zaG9wIDMu",
    "MAA4QklNBAQAAAAAAAA4QklNBCUAAAAAABDUHYzZjwCyBOmACZjs+EJ+/8AAEQgACAAIAwEiAAIR",
    "AQMRAf/EAB8AAAEFAQEBAQEBAAAAAAAAAAABAgMEBQYHCAkKC//EALUQAAIBAwMCBAMFBQQEAAAB",
    "fQECAwAEEQUSITFBBhNRYQcicRQygZGhCCNCscEVUtHwJDNicoIJChYXGBkaJSYnKCkqNDU2Nzg5",
    "OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6g4SFhoeIiYqSk5SVlpeYmZqio6Slpqeo",
    "qaqys7S1tre4ubrCw8TFxsfIycrS09TV1tfY2drh4uPk5ebn6Onq8fLz9PX29/j5+v/EAB8BAAMB",
    "AQEBAQEBAQEAAAAAAAABAgMEBQYHCAkKC//EALURAAIBAgQEAwQHBQQEAAECdwABAgMRBAUhMQYS",
    "QVEHYXETIjKBCBRCkaGxwQkjM1LwFWJy0QoWJDThJfEXGBkaJicoKSo1Njc4OTpDREVGR0hJSlNU",
    "VVZXWFlaY2RlZmdoaWpzdHV2d3h5eoKDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5",
    "usLDxMXGx8jJytLT1NXW19jZ2uLj5OXm5+jp6vLz9PX29/j5+v/bAEMAAgICAgICAwICAwUDAwMF",
    "BgUFBQUGCAYGBgYGCAoICAgICAgKCgoKCgoKCgwMDAwMDA4ODg4ODw8PDw8PDw8PD//bAEMBAgIC",
    "BAQEBwQEBxALCQsQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQEBAQ",
    "EBAQEP/dAAQAAf/aAAwDAQACEQMRAD8A+Zv+Sv8A/Y//APp//wDvn/6W/wDX7/x+n/DPnx7/AOia",
    "+Jv/AATXv/xqj9nz/kvfw1/7GbRv/S2Kv6la/sDOc5q4GqqNFLltfW+mr0Wq000XTZaWS/LsJhI1",
    "o889z//Z"
  ]

  def png_bytes, do: Base.decode64!(IO.iodata_to_binary(@png))
  def jpg_bytes, do: Base.decode64!(IO.iodata_to_binary(@jpg))

  @doc "A whole PNG that is `side` pixels wide and high: 1 bit per pixel, so a big one is still small."
  def png_of_size(side) do
    row = <<0>> <> :binary.copy(<<0>>, div(side + 7, 8))
    ihdr = <<side::32, side::32, 1, 0, 0, 0, 0>>
    data = :zlib.compress(:binary.copy(row, side))

    <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A>> <>
      chunk("IHDR", ihdr) <> chunk("IDAT", data) <> chunk("IEND", "")
  end

  defp chunk(type, data),
    do: <<byte_size(data)::32>> <> type <> data <> <<:erlang.crc32([type, data])::32>>

  @doc "A JPEG start that says it is `side` pixels wide and high (the rest of the file is missing)."
  def jpg_header(side) do
    <<0xFF, 0xD8, 0xFF, 0xC0, 17::16, 8, side::16, side::16, 3, 1, 0x22, 0, 2, 0x11, 1, 3, 0x11,
      1>>
  end

  @doc "Writes `bytes` to a temp file that is removed when the test ends, and returns its path."
  def tmp_file(bytes) do
    path = Path.join(System.tmp_dir!(), "quickslips-test-#{System.unique_integer([:positive])}")
    File.write!(path, bytes)
    ExUnit.Callbacks.on_exit(fn -> File.rm(path) end)
    path
  end

  @doc """
  Stores a picture for the user the way the upload code does, and returns its relative path
  (`"12/a1b2c3d4e5f60718.png"`). The user's folder is removed when the test ends.
  """
  def stored_image(user_id, bytes \\ png_bytes()) do
    ExUnit.Callbacks.on_exit(fn ->
      File.rm_rf(Path.join(Uploads.root(), Integer.to_string(user_id)))
    end)

    {:ok, relative} = Uploads.store(user_id, tmp_file(bytes))
    relative
  end
end
