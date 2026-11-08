defmodule QuickSlips.Contact do
  @moduledoc """
  The contact form: what a visitor writes to the owner of the site about a change they would like, feedback, a
  problem or a dispute.

  A message is kept in the database (`contact_messages`, one `QuickSlips.Contact.Message` each) so that it can be
  found again, and two e-mails follow it (`QuickSlips.Contact.Notifier`): one tells the owner, at `CONTACT_EMAIL`
  (`QuickSlips.Site.contact_email/0`), with the sender as Reply-To; one tells the sender that it arrived. They are
  sent after the message is saved, by a task that does not hold the visitor up, and a failure of either is logged
  and left visible on the message (`owner_notified_at` and `confirmation_sent_at` stay empty) without losing it.
  The owner reads the messages at `/admin/messages`, which only the admins (`ADMIN_EMAILS`) can open.

  A mailbox can be flooded, and a confirmation can be sent to an address that is not the sender's, so there are
  ceilings for a day (`:contact_limits`): one for the whole site, one for each logged-in user, and one for each
  address that a confirmation is sent to. They are counted with the download counters (`QuickSlips.Quota`), under
  keys that start with `contact:`. Whether the sender is a person is for Turnstile to say; the page asks it, for
  everybody, before it calls `submit/2`.
  """
  import Ecto.Query
  require Logger

  alias QuickSlips.Accounts
  alias QuickSlips.Accounts.Scope
  alias QuickSlips.Contact.{Message, Notifier}
  alias QuickSlips.{Locales, Quota, Repo, Site}

  @pubsub_topic "contact:messages"

  ## The visitor's side

  @doc "Whether a message can be taken at all: there is an address to tell."
  def available?, do: Site.contact_email() != nil

  @doc "A changeset of the form, for `to_form/2`."
  def change_message(%Message{} = message \\ %Message{}, attrs \\ %{}),
    do: Message.changeset(message, attrs)

  @doc """
  Checks what the visitor wrote: `{:ok, message}` when it is fine, and `{:error, changeset}` with the reasons when
  it is not.
  """
  def review(attrs) do
    %Message{} |> Message.changeset(attrs) |> Ecto.Changeset.apply_action(:insert)
  end

  @doc """
  Keeps `message` and tells the owner and the sender. `context` is what the page knows: `:user` (the logged-in user,
  or `nil`), `:locale` (the `QuickSlips.Locales` locale of the page: its code and the language of the confirmation),
  `:page` (a path of this site that the visitor is writing about, or `nil`) and `:site_url` (the address of the
  site, for the links in the e-mails).

  Returns `{:ok, message}`, the message as it was kept (with its `reference`), or `{:error, reason}` with a reason
  of `:unavailable` (there is no address to tell), `:limit` (the ceiling of the day is reached) or `:storage` (it
  could not be kept; what was counted is given back).

  A message with the robot trap filled in is not kept, and the sender is given a reference all the same, so that it
  learns nothing.
  """
  def submit(%Message{} = message, context) do
    if robot?(message) do
      {:ok, %{message | reference: reference(), website: nil}}
    else
      with {:ok, owner} <- address(),
           {:ok, claimed} <- claim(context[:user]),
           {:ok, saved} <- save(message, context, claimed) do
        broadcast({:created, saved})
        tell_later(saved, owner, context)
        {:ok, saved}
      end
    end
  end

  defp robot?(%Message{website: website}), do: is_binary(website) and String.trim(website) != ""

  defp address do
    case Site.contact_email() do
      nil -> {:error, :unavailable}
      owner -> {:ok, owner}
    end
  end

  # Takes one message from the ceiling of the user (when there is one) and one from the ceiling of the site; if
  # either is full, what was taken is given back.
  defp claim(user) do
    limits = limits()

    slots =
      if(user, do: [{"contact:u:#{user.id}", limits.user}], else: []) ++
        [{"contact:all", limits.all}]

    Enum.reduce_while(slots, {:ok, []}, fn {key, limit}, {:ok, taken} ->
      case Quota.check_and_increment(key, limit) do
        {:ok, _left} ->
          {:cont, {:ok, [key | taken]}}

        {:error, :limit_reached} ->
          Enum.each(taken, &Quota.refund/1)
          {:halt, {:error, :limit}}
      end
    end)
  end

  defp limits do
    Map.merge(
      %{user: 5, all: 100, to: 3},
      Map.new(Application.get_env(:quickslips, :contact_limits, []))
    )
  end

  defp save(message, context, claimed) do
    user = context[:user]

    message = %{
      message
      | reference: reference(),
        locale: Locales.hreflang(context.locale),
        page: context[:page],
        user_id: user && user.id,
        website: nil
    }

    {:ok, Repo.insert!(message)}
  rescue
    error ->
      Enum.each(claimed, &Quota.refund/1)

      Logger.error(
        "A message from the contact form could not be kept: #{Exception.message(error)}"
      )

      {:error, :storage}
  end

  # Eight letters and digits, in two groups, like "K3F9-Q27A": what the sender is given and the owner searches for.
  # It has no 0, 1 or 8, so it is hard to misread.
  defp reference do
    <<first::binary-size(4), second::binary-size(4)>> =
      Base.encode32(:crypto.strong_rand_bytes(5), padding: false)

    first <> "-" <> second
  end

  ## The e-mails

  # After the message is kept, so that nothing is lost if the mail provider is down, and in a task of its own, so
  # that the visitor does not wait for two connections to a mail server.
  defp tell_later(message, owner, context) do
    {:ok, _pid} =
      Task.Supervisor.start_child(QuickSlips.TaskSupervisor, fn ->
        tell(message, owner, context)
      end)

    :ok
  end

  defp tell(message, owner, context) do
    message =
      if attempt("to the owner", fn -> Notifier.deliver_to_owner(message, owner, context) end),
        do: mark(message, :owner_notified_at),
        else: message

    # A confirmation goes to an address that anybody could have typed, so one address gets only a few of them.
    if confirm?(message.email) and
         attempt("to the sender", fn -> Notifier.deliver_confirmation(message, owner, context) end) do
      mark(message, :confirmation_sent_at)
    end

    :ok
  end

  # True when the e-mail went out. A mail provider that is down can answer with an error or raise one; both are
  # logged without what the visitor wrote.
  defp attempt(what, send) do
    case send.() do
      {:ok, _email} ->
        true

      {:error, reason} ->
        Logger.error("An e-mail #{what} about a contact message was not sent: #{inspect(reason)}")
        false
    end
  rescue
    error ->
      Logger.error(
        "An e-mail #{what} about a contact message was not sent: #{Exception.message(error)}"
      )

      false
  end

  # The counter is kept under a hash of the address, so that the table of counters holds no address.
  defp confirm?(email) do
    hash = :crypto.hash(:sha256, String.downcase(email)) |> Base.encode16(case: :lower)

    case Quota.check_and_increment("contact:to:" <> hash, limits().to) do
      {:ok, _left} ->
        true

      {:error, :limit_reached} ->
        Logger.info(
          "No confirmation of a contact message: the address has had its share for today"
        )

        false
    end
  end

  # Says on the message that an e-mail went out, and tells the pages that show it.
  defp mark(message, field) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Repo.update_all(from(m in Message, where: m.id == ^message.id),
      set: [{field, now}, {:updated_at, now}]
    )

    message = Map.put(message, field, now)
    broadcast({:updated, message})
    message
  end

  ## The owner's side

  @doc """
  Subscribes to what happens to the messages, for a page that shows them. Only an admin can.

  The messages match the pattern:

    * `{:created, %Message{}}`
    * `{:updated, %Message{}}`
    * `{:deleted, %Message{}}`

  """
  def subscribe_messages(%Scope{} = scope) do
    admin!(scope)
    Phoenix.PubSub.subscribe(QuickSlips.PubSub, @pubsub_topic)
  end

  defp broadcast(event), do: Phoenix.PubSub.broadcast(QuickSlips.PubSub, @pubsub_topic, event)

  @doc """
  The messages, newest first, a page at a time: `%{messages: [...], total: _, page: _, pages: _}`.

  The options: `:status` and `:topic` (one of `Message.statuses/0` and `Message.topics/0`), `:search` (a word of the
  reference, the address, the name or the message), `:page` (from 1) and `:per_page` (25).
  """
  def list_messages(%Scope{} = scope, opts \\ []) do
    admin!(scope)

    per_page = Keyword.get(opts, :per_page, 25)
    query = filter(Message, opts)
    total = Repo.aggregate(query, :count)
    pages = max(div(total + per_page - 1, per_page), 1)
    page = opts |> Keyword.get(:page, 1) |> max(1) |> min(pages)

    messages =
      query
      |> order_by([m], desc: m.inserted_at, desc: m.id)
      |> limit(^per_page)
      |> offset(^((page - 1) * per_page))
      |> Repo.all()

    %{messages: messages, total: total, page: page, pages: pages}
  end

  defp filter(query, opts) do
    query
    |> filter_status(opts[:status])
    |> filter_topic(opts[:topic])
    |> filter_search(opts[:search])
  end

  defp filter_status(query, nil), do: query
  defp filter_status(query, status), do: where(query, [m], m.status == ^status)

  defp filter_topic(query, nil), do: query
  defp filter_topic(query, topic), do: where(query, [m], m.topic == ^topic)

  defp filter_search(query, nil), do: query

  defp filter_search(query, term) do
    case String.trim(term) do
      "" ->
        query

      term ->
        pattern = "%" <> escape_like(term) <> "%"

        where(
          query,
          [m],
          ilike(m.reference, ^pattern) or ilike(m.email, ^pattern) or ilike(m.name, ^pattern) or
            ilike(m.message, ^pattern)
        )
    end
  end

  # What was typed is a word to look for, not a pattern: `%` and `_` mean themselves.
  defp escape_like(term), do: String.replace(term, ["\\", "%", "_"], &("\\" <> &1))

  @doc "How many messages there are: `%{all: _, new: _, read: _, resolved: _}`."
  def count_messages(%Scope{} = scope) do
    admin!(scope)

    counts =
      from(m in Message, group_by: m.status, select: {m.status, count(m.id)})
      |> Repo.all()
      |> Map.new()

    for status <- Message.statuses(), into: %{all: counts |> Map.values() |> Enum.sum()} do
      {status, Map.get(counts, status, 0)}
    end
  end

  @doc "A message, with the account that wrote it (if any). Raises `Ecto.NoResultsError` if there is none."
  def get_message!(%Scope{} = scope, id) do
    admin!(scope)
    Message |> Repo.get!(id) |> Repo.preload(:user)
  end

  @doc "Says where the message stands: one of `Message.statuses/0`."
  def set_status(%Scope{} = scope, %Message{} = message, status)
      when status in [:new, :read, :resolved] do
    admin!(scope)

    with {:ok, message} <- message |> Ecto.Changeset.change(status: status) |> Repo.update() do
      broadcast({:updated, message})
      {:ok, message}
    end
  end

  @doc "Deletes a message for good: what its sender asked to be forgotten, or what is not worth keeping."
  def delete_message(%Scope{} = scope, %Message{} = message) do
    admin!(scope)

    with {:ok, message} <- Repo.delete(message) do
      broadcast({:deleted, message})
      {:ok, message}
    end
  end

  # The pages for the owner check who is asking, and so does this: a page that forgets to is not the only thing
  # between a visitor and everybody's messages.
  defp admin!(%Scope{user: user}) do
    Accounts.admin?(user) ||
      raise ArgumentError, "only an admin can read the messages of the contact form"
  end
end
