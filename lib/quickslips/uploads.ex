defmodule QuickSlips.Uploads do
  @moduledoc "Stores user images in a private folder after checking what they really are."

  # A 1 MB PNG can unpack into a picture with hundreds of millions of pixels, which would make Typst
  # use all the memory it can get. No logo or signature needs more than this on a side.
  @max_side 4_000

  # The size of the file itself. The upload forms (LiveView) stop a bigger file before it gets here; a request that
  # does not come from them (the quick save on a bill's page) is checked here.
  @max_bytes 1_000_000

  def root, do: Application.fetch_env!(:quickslips, :uploads_dir)

  @doc "The largest picture file we keep, in bytes."
  def max_file_size, do: @max_bytes

  @doc "Absolute path for a stored relative path like \"12/a1b2c3d4e5f60718.png\"."
  def path(relative), do: Path.join(root(), relative)

  @doc """
  Copies the uploaded temp file into the user's folder.
  Returns `{:ok, relative_path}`, `{:error, :unsupported_type}` (not a PNG or JPEG),
  `{:error, :too_large}` (more than #{@max_side} pixels on a side) or `{:error, :file_too_large}` (the file is
  over #{@max_bytes} bytes).
  """
  def store(user_id, tmp_path) do
    with {:ok, ext} <- detect(tmp_path) do
      relative = Path.join(Integer.to_string(user_id), random_name() <> ext)
      destination = path(relative)
      File.mkdir_p!(Path.dirname(destination))
      File.cp!(tmp_path, destination)
      {:ok, relative}
    end
  end

  @doc "Removes a stored file. A file that is already gone is fine."
  def delete(nil), do: :ok

  def delete(relative) do
    _ = File.rm(path(relative))
    :ok
  end

  defp detect(file) do
    with {:ok, %File.Stat{size: size}} when size <= @max_bytes <- File.stat(file),
         {:ok, bytes} <- File.read(file) do
      check(bytes)
    else
      {:ok, %File.Stat{}} -> {:error, :file_too_large}
      {:error, _reason} -> {:error, :unsupported_type}
    end
  end

  # PNG: the signature, then the first chunk, which is always IHDR and starts with width and height.
  defp check(
         <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, _length::32, "IHDR", width::32, height::32,
           _::binary>> = png
       ) do
    with {:ok, ext} <- within_limits(".png", width, height) do
      if png_whole?(png), do: {:ok, ext}, else: {:error, :unsupported_type}
    end
  end

  defp check(<<0xFF, 0xD8, 0xFF, _::binary>> = jpeg) do
    case jpeg_size(jpeg) do
      {:ok, width, height} -> within_limits(".jpg", width, height)
      :error -> {:error, :unsupported_type}
    end
  end

  defp check(_other), do: {:error, :unsupported_type}

  defp within_limits(ext, width, height) when width in 1..@max_side and height in 1..@max_side,
    do: {:ok, ext}

  defp within_limits(_ext, _width, _height), do: {:error, :too_large}

  # A PNG is a list of chunks (length, type, data, checksum) that ends with IEND. Walk them, so a file that
  # was cut short or damaged is turned down now, and not later inside Typst, when somebody downloads a bill.
  defp png_whole?(<<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, chunks::binary>>), do: png_chunks(chunks)

  defp png_chunks(
         <<length::32, type::binary-size(4), data::binary-size(length), crc::32, rest::binary>>
       ) do
    cond do
      :erlang.crc32([type, data]) != crc -> false
      type == "IEND" -> true
      true -> png_chunks(rest)
    end
  end

  defp png_chunks(_cut_short), do: false

  # A JPEG is a list of segments (0xFF, a marker byte, a 2-byte length, the content). The size sits
  # in the "start of frame" segment, so skip the segments before it.
  defp jpeg_size(<<0xFF, 0xD8, segments::binary>>), do: jpeg_segments(segments)

  defp jpeg_segments(<<0xFF, 0xFF, rest::binary>>), do: jpeg_segments(<<0xFF, rest::binary>>)

  defp jpeg_segments(<<0xFF, marker, _length::16, _precision, height::16, width::16, _::binary>>)
       when marker in 0xC0..0xCF and marker not in [0xC4, 0xC8, 0xCC],
       do: {:ok, width, height}

  defp jpeg_segments(<<0xFF, marker, length::16, rest::binary>>)
       when marker not in 0xD0..0xD9 and length >= 2 do
    skip = length - 2

    case rest do
      <<_content::binary-size(^skip), next::binary>> -> jpeg_segments(next)
      _truncated -> :error
    end
  end

  defp jpeg_segments(_other), do: :error

  defp random_name, do: 8 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)
end
