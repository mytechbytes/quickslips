defmodule QuickSlips.BusinessesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `QuickSlips.Businesses` context.
  """

  @doc """
  Generate a business.
  """
  def business_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        address: "some address",
        gstin: "29ABCDE1234F1Z5",
        name: "some name"
      })

    {:ok, business} = QuickSlips.Businesses.create_business(scope, attrs)
    business
  end
end
