defmodule QuickSlips.ContactFixtures do
  @moduledoc """
  Test helpers for creating the messages of the contact form as they are kept, without the form, the checks, the
  ceilings and the e-mails (those are tested with `QuickSlips.Contact.submit/2`).
  """
  alias QuickSlips.Contact.Message
  alias QuickSlips.Repo

  @doc """
  Keeps a message. Anything of `QuickSlips.Contact.Message` can be given, like `status: :read` or
  `inserted_at: ~U[2026-11-01 09:00:00Z]`; the rest is made up, and different for each call.
  """
  def message_fixture(attrs \\ %{}) do
    n = System.unique_integer([:positive])

    attrs =
      Enum.into(attrs, %{
        reference: "FX#{n}",
        topic: :feedback,
        name: "Sender #{n}",
        email: "sender#{n}@example.com",
        message: "A message, number #{n}.",
        locale: "en-IN",
        status: :new
      })

    Message |> struct!(attrs) |> Repo.insert!()
  end
end
