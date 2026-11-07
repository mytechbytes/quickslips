defmodule QuickSlips.UploadsTest do
  use ExUnit.Case, async: true

  import QuickSlips.UploadsFixtures

  alias QuickSlips.Uploads

  # A user id no database row will ever have, so this test only touches its own folder.
  @user_id 987_654_321

  setup do
    on_exit(fn -> File.rm_rf(Path.join(Uploads.root(), Integer.to_string(@user_id))) end)
  end

  describe "store/2" do
    test "keeps a PNG under the user's folder, with a name we made up" do
      assert {:ok, relative} = Uploads.store(@user_id, tmp_file(png_bytes()))

      assert relative =~ ~r/^#{@user_id}\/[a-f0-9]{16}\.png$/
      assert File.read!(Uploads.path(relative)) == png_bytes()
    end

    test "keeps a JPEG, even when other segments come before the picture data" do
      assert {:ok, relative} = Uploads.store(@user_id, tmp_file(jpg_bytes()))
      assert relative =~ ~r/\.jpg$/
    end

    test "decides by the content, not by the name" do
      path = tmp_file("<svg xmlns='http://www.w3.org/2000/svg'><script>alert(1)</script></svg>")
      assert {:error, :unsupported_type} = Uploads.store(@user_id, path)
      assert {:error, :unsupported_type} = Uploads.store(@user_id, tmp_file("just some text"))
      assert {:error, :unsupported_type} = Uploads.store(@user_id, tmp_file(""))
    end

    test "refuses a file that starts like a PNG or JPEG but is cut short" do
      assert {:error, :unsupported_type} =
               Uploads.store(@user_id, tmp_file(<<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A>>))

      assert {:error, :unsupported_type} =
               Uploads.store(@user_id, tmp_file(<<0xFF, 0xD8, 0xFF, 0xE0, 0, 16>>))
    end

    test "refuses a PNG that is cut short or damaged" do
      png = png_bytes()
      cut = binary_part(png, 0, byte_size(png) - 12)
      # flip one bit in the picture data, which is in the middle of the file
      middle = div(byte_size(png), 2)
      <<before::binary-size(^middle), byte, rest::binary>> = png
      damaged = <<before::binary, Bitwise.bxor(byte, 1), rest::binary>>

      assert {:error, :unsupported_type} = Uploads.store(@user_id, tmp_file(cut))
      assert {:error, :unsupported_type} = Uploads.store(@user_id, tmp_file(damaged))
    end

    test "refuses a picture with too many pixels on a side" do
      assert {:ok, _} = Uploads.store(@user_id, tmp_file(png_of_size(4_000)))
      assert {:error, :too_large} = Uploads.store(@user_id, tmp_file(png_of_size(4_001)))
      assert {:error, :too_large} = Uploads.store(@user_id, tmp_file(jpg_header(20_000)))
    end

    test "refuses a file over 1 MB, however good the picture" do
      big = png_bytes() <> :binary.copy(<<0>>, Uploads.max_file_size())

      assert {:error, :file_too_large} = Uploads.store(@user_id, tmp_file(big))
      refute File.exists?(Path.join(Uploads.root(), Integer.to_string(@user_id)))
    end

    test "stores nothing when it refuses" do
      assert {:error, :unsupported_type} = Uploads.store(@user_id, tmp_file("text"))
      refute File.exists?(Path.join(Uploads.root(), Integer.to_string(@user_id)))
    end
  end

  describe "delete/1" do
    test "removes the file" do
      {:ok, relative} = Uploads.store(@user_id, tmp_file(png_bytes()))

      assert :ok = Uploads.delete(relative)
      refute File.exists?(Uploads.path(relative))
    end

    test "a missing file, or no path at all, is fine" do
      assert :ok = Uploads.delete(nil)
      assert :ok = Uploads.delete("#{@user_id}/0000000000000000.png")
    end
  end
end
