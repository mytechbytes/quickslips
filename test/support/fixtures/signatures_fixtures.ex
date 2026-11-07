defmodule QuickSlips.SignaturesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `QuickSlips.Signatures` context.
  """

  import QuickSlips.UploadsFixtures, only: [png_bytes: 0, tmp_file: 1]

  @doc """
  Generate a signature of the user of `scope`. The picture (`bytes`, a PNG unless told otherwise) is stored the way
  the upload code does, and the user's folder is removed when the test ends.
  """
  def signature_fixture(scope, attrs \\ %{}, bytes \\ png_bytes()) do
    attrs = Enum.into(attrs, %{name: "Signature #{System.unique_integer([:positive])}"})
    folder = Path.join(QuickSlips.Uploads.root(), Integer.to_string(scope.user.id))
    ExUnit.Callbacks.on_exit(fn -> File.rm_rf(folder) end)

    {:ok, signature} = QuickSlips.Signatures.create_signature(scope, attrs, tmp_file(bytes))
    signature
  end
end
