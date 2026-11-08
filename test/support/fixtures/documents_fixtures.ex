defmodule QuickSlips.DocumentsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `QuickSlips.Documents` context.
  """

  @doc """
  Generate a document. `business` is the saved business it was made with, if any, and `signature` the saved
  signature that was drawn on it, and `stamp` the revenue stamp (`{:system, id}`, or a saved one).
  """
  def document_fixture(scope, attrs \\ %{}, business \\ nil, signature \\ nil, stamp \\ nil) do
    attrs =
      Enum.into(attrs, %{
        data: %{},
        slug: "fuel-bill",
        template: "t1",
        title: "some title"
      })

    {:ok, document} =
      QuickSlips.Documents.create_document(scope, attrs, business, signature, stamp)

    document
  end
end
