defmodule QuickSlips.StampsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `QuickSlips.Stamps` context.
  """

  import QuickSlips.UploadsFixtures, only: [png_bytes: 0, tmp_file: 1]

  @doc """
  Generate a stamp of the user of `scope`. The picture (`bytes`, a PNG unless told otherwise) is stored the way
  the upload code does, and the user's folder is removed when the test ends.
  """
  def stamp_fixture(scope, attrs \\ %{}, bytes \\ png_bytes()) do
    attrs = Enum.into(attrs, %{name: "Stamp #{System.unique_integer([:positive])}"})
    folder = Path.join(QuickSlips.Uploads.root(), Integer.to_string(scope.user.id))
    ExUnit.Callbacks.on_exit(fn -> File.rm_rf(folder) end)

    {:ok, stamp} = QuickSlips.Stamps.create_stamp(scope, attrs, tmp_file(bytes))
    stamp
  end
end
