defmodule QuickSlips.Contact.Message do
  @moduledoc """
  What a visitor writes in the contact form (`/contact`), and what is kept of it (`contact_messages`).

  The form fills in the topic, the name, the address and the message; the rest is set by `QuickSlips.Contact` when
  the message is saved (the reference, the language and country of the page, the page it is about, who was logged
  in) or by the owner (the status), so none of it can come from the form.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @topics [:change, :feedback, :problem, :complaint, :other]

  # `new` until the owner opens it, `read` after, and `resolved` once it has been dealt with.
  @statuses [:new, :read, :resolved]

  # An address with no space, comma, semicolon, colon, quote, angle bracket, parenthesis, square bracket or
  # backslash, one @, and a dot in what follows it. Those characters could only be there to break the header of the
  # e-mail that carries the address (Reply-To, To).
  @address ~r/\A[^\s@<>"(),;:\[\]\\]+@[^\s@<>"(),;:\[\]\\]+\.[^\s@<>"(),;:\[\]\\]+\z/u

  schema "contact_messages" do
    field :reference, :string
    field :topic, Ecto.Enum, values: @topics, default: :feedback
    field :name, :string
    field :email, :string
    field :message, :string
    field :locale, :string
    field :page, :string
    field :status, Ecto.Enum, values: @statuses, default: :new
    field :owner_notified_at, :utc_datetime
    field :confirmation_sent_at, :utc_datetime

    # The trap for robots: nobody sees this field, so a message with something in it was not written by a person.
    # It is never kept.
    field :website, :string, virtual: true

    belongs_to :user, QuickSlips.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc "The kinds of message, in the order the form lists them."
  def topics, do: @topics

  @doc "What the owner can say of a message, in the order of its life."
  def statuses, do: @statuses

  @doc """
  A changeset for the form. A name is optional; an address and a message are not, and the message must say
  something (a few characters at least) without being a novel.
  """
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:topic, :name, :email, :message, :website])
    |> update_change(:name, &one_line/1)
    |> update_change(:email, &String.trim/1)
    |> validate_required([:topic, :email, :message])
    |> validate_length(:name, max: 100)
    |> validate_length(:email, max: 160)
    |> validate_format(:email, @address)
    |> validate_length(:message, min: 5, max: 4000)
  end

  # A name is a line: line breaks and runs of spaces in it become one space, and nothing left is no name.
  defp one_line(name) do
    case name |> String.replace(~r/\s+/u, " ") |> String.trim() do
      "" -> nil
      line -> line
    end
  end
end
