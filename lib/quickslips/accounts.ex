defmodule QuickSlips.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false

  require Logger

  alias QuickSlips.Repo

  alias QuickSlips.Accounts.{User, UserToken, UserNotifier}

  ## Database getters

  @doc """
  Gets a user by email.

  ## Examples

      iex> get_user_by_email("foo@example.com")
      %User{}

      iex> get_user_by_email("unknown@example.com")
      nil

  """
  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: email)
  end

  @doc """
  Gets a user by email and password.

  ## Examples

      iex> get_user_by_email_and_password("foo@example.com", "correct_password")
      %User{}

      iex> get_user_by_email_and_password("foo@example.com", "invalid_password")
      nil

  """
  def get_user_by_email_and_password(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: email)
    if User.valid_password?(user, password), do: user
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  ## User registration

  @doc """
  Registers a user.

  ## Examples

      iex> register_user(%{field: value})
      {:ok, %User{}}

      iex> register_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def register_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Registers a user for the sign-up page, which must not tell a visitor whether an address already has an account:
  whoever could ask for any address and read the answer would be able to list the people who use the site.

  Returns `{:ok, email}` when the account was made, *and also when the address already had one*; in both cases the
  e-mail that logs in or confirms (see `send_login_instructions_later/3`) goes to the owner of the address and the page
  says the same. For an address that has an account the e-mail is the way the owner learns of it. Returns `{:error,
  changeset}` for what is wrong with the form itself (a short password, no @), which is the same whatever the address, and
  never with the "has already been taken" of the e-mail.

  `opts` is passed on to the e-mail: `:locale` is the locale the visitor chose on the site, whose language the e-mail
  is written in.
  """
  def register_user_quietly(attrs, magic_link_url_fun, opts \\ []) do
    case register_user(attrs) do
      {:ok, user} ->
        send_login_instructions_later(user.email, magic_link_url_fun, opts)
        {:ok, user.email}

      {:error, %Ecto.Changeset{} = changeset} ->
        case Enum.split_with(changeset.errors, &email_taken?/1) do
          {[], _others} ->
            {:error, changeset}

          {_taken, []} ->
            # Nothing else is wrong, so a new address would have had its password hashed (the part that takes time),
            # and the taken one was refused before that. Do the same work, so the answer comes as slowly.
            Bcrypt.no_user_verify()
            email = Ecto.Changeset.get_field(changeset, :email)
            send_login_instructions_later(email, magic_link_url_fun, opts)
            {:ok, email}

          {_taken, others} ->
            {:error, %{changeset | errors: others}}
        end
    end
  end

  # What `unsafe_validate_unique` (in the form) and `unique_constraint` (when the database says no) put on the e-mail.
  defp email_taken?({:email, {_message, options}}),
    do: options[:validation] == :unsafe_unique or options[:constraint] == :unique

  defp email_taken?(_error), do: false

  @doc """
  Returns a changeset for the registration form (no hashing, no uniqueness query).
  """
  def change_user_registration(%User{} = user, attrs \\ %{}, opts \\ []) do
    User.registration_changeset(user, attrs, opts)
  end

  ## Admins

  @doc """
  Whether the user may open the admin pages (the error dashboard).

  The people are listed in the `ADMIN_EMAILS` environment variable, so nobody is an admin until you say who
  is. An account whose address was never confirmed doesn't count: anyone can register an address that is
  not theirs, and logging in with a password does not ask for the confirmation.
  """
  def admin?(%User{email: email, confirmed_at: %DateTime{}}) do
    String.downcase(email) in Application.get_env(:quickslips, :admin_emails, [])
  end

  def admin?(_user), do: false

  ## Settings

  @doc """
  Checks whether the user is in sudo mode.

  The user is in sudo mode when the last authentication was done no further
  than 20 minutes ago. The limit can be given as second argument in minutes.
  """
  def sudo_mode?(user, minutes \\ -20)

  def sudo_mode?(%User{authenticated_at: ts}, minutes) when is_struct(ts, DateTime) do
    DateTime.after?(ts, DateTime.utc_now() |> DateTime.add(minutes, :minute))
  end

  def sudo_mode?(_user, _minutes), do: false

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user email.

  See `QuickSlips.Accounts.User.email_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_email(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_email(user, attrs \\ %{}, opts \\ []) do
    User.email_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user email using the given token.

  If the token matches, the user email is updated and the token is deleted.
  """
  def update_user_email(user, token) do
    context = "change:#{user.email}"

    Repo.transact(fn ->
      with {:ok, query} <- UserToken.verify_change_email_token_query(token, context),
           %UserToken{sent_to: email} <- Repo.one(query),
           {:ok, user} <- Repo.update(User.email_changeset(user, %{email: email})),
           {_count, _result} <-
             Repo.delete_all(from(UserToken, where: [user_id: ^user.id, context: ^context])) do
        {:ok, user}
      else
        _ -> {:error, :transaction_aborted}
      end
    end)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for changing the user password.

  See `QuickSlips.Accounts.User.password_changeset/3` for a list of supported options.

  ## Examples

      iex> change_user_password(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user_password(user, attrs \\ %{}, opts \\ []) do
    User.password_changeset(user, attrs, opts)
  end

  @doc """
  Updates the user password.

  Returns a tuple with the updated user, as well as a list of expired tokens.

  ## Examples

      iex> update_user_password(user, %{password: ...})
      {:ok, {%User{}, [...]}}

      iex> update_user_password(user, %{password: "too short"})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_password(user, attrs) do
    user
    |> User.password_changeset(attrs)
    |> update_user_and_delete_all_tokens()
  end

  ## Session

  @doc """
  Generates a session token.
  """
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Gets the user with the given signed token.

  If the token is valid `{user, token_inserted_at}` is returned, otherwise `nil` is returned.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc """
  Gets the user with the given magic link token.
  """
  def get_user_by_magic_link_token(token) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {user, _token} <- Repo.one(query) do
      user
    else
      _ -> nil
    end
  end

  @doc """
  Logs the user in by magic link.

  There are three cases to consider:

  1. The user has already confirmed their email. They are logged in
     and the magic link is expired.

  2. The user has not confirmed their email and no password is set.
     In this case, the user gets confirmed, logged in, and all tokens -
     including session ones - are expired. In theory, no other tokens
     exist but we delete all of them for best security practices.

  3. The user has not confirmed their email but a password is set.
     This cannot happen in the default implementation but may be the
     source of security pitfalls. See the "Mixing magic link and password registration" section of
     `mix help phx.gen.auth`.
  """
  def login_user_by_magic_link(token) do
    {:ok, query} = UserToken.verify_magic_link_token_query(token)

    case Repo.one(query) do
      # Unconfirmed users who have a password must confirm with
      # confirm_user_with_password/2 (see below), not with the link alone.
      {%User{confirmed_at: nil, hashed_password: hash}, _token} when not is_nil(hash) ->
        {:error, :password_required}

      {%User{confirmed_at: nil} = user, _token} ->
        user
        |> User.confirm_changeset()
        |> update_user_and_delete_all_tokens()

      {user, token} ->
        Repo.delete!(token)
        {:ok, {user, []}}

      nil ->
        {:error, :not_found}
    end
  end

  @doc """
  Confirms an account that was registered with a password.

  Holding the emailed token is not enough: the caller must also know the password
  chosen at registration. This stops an attacker from pre-registering someone
  else's email with a password only the attacker knows.

  Returns `{:ok, {user, expired_tokens}}` or `{:error, :invalid}`.
  """
  def confirm_user_with_password(token, password) when is_binary(token) and is_binary(password) do
    with {:ok, query} <- UserToken.verify_magic_link_token_query(token),
         {%User{confirmed_at: nil} = user, _token} <- Repo.one(query),
         true <- User.valid_password?(user, password) do
      user
      |> User.confirm_changeset()
      |> update_user_and_delete_all_tokens()
    else
      _ -> {:error, :invalid}
    end
  end

  @doc ~S"""
  Delivers the update email instructions to the given user.

  `opts` is passed on to the e-mail: `:locale` is the locale the person chose on the site, whose language the e-mail
  is written in.

  ## Examples

      iex> deliver_user_update_email_instructions(user, current_email, &url(~p"/users/settings/confirm-email/#{&1}"))
      {:ok, %{to: ..., body: ...}}

  """
  def deliver_user_update_email_instructions(
        %User{} = user,
        current_email,
        update_email_url_fun,
        opts \\ []
      )
      when is_function(update_email_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "change:#{current_email}")

    Repo.insert!(user_token)

    UserNotifier.deliver_update_email_instructions(
      user,
      update_email_url_fun.(encoded_token),
      opts
    )
  end

  @doc """
  Delivers the magic link login instructions to the given user. `opts` is passed on to the e-mail (`:locale`, the
  locale the person chose on the site, whose language the e-mail is written in).
  """
  def deliver_login_instructions(%User{} = user, magic_link_url_fun, opts \\ [])
      when is_function(magic_link_url_fun, 1) do
    {encoded_token, user_token} = UserToken.build_email_token(user, "login")
    Repo.insert!(user_token)
    UserNotifier.deliver_login_instructions(user, magic_link_url_fun.(encoded_token), opts)
  end

  @doc """
  Sends the e-mail that logs in the owner of `email` (or confirms their account, if it was never confirmed) from a
  task of its own, and says nothing of whether there is an account for the address.

  The look-up, the token and the sending are all in the task. Sending takes a second or more and the look-up of an
  address that has no account takes nothing, so a page that did them itself would answer slowly for an address that has
  an account and at once for one that has none, and whoever timed it would know which addresses are registered.

  The task has no language of its own, so the language of the e-mail is passed in `opts` as `:locale`: the locale the
  visitor chose on the site, which the page they are on knows (`socket.assigns.locale`).
  """
  def send_login_instructions_later(email, magic_link_url_fun, opts \\ [])
      when is_binary(email) and is_function(magic_link_url_fun, 1) do
    {:ok, _pid} =
      Task.Supervisor.start_child(QuickSlips.TaskSupervisor, fn ->
        with %User{} = user <- get_user_by_email(email),
             {:error, reason} <- deliver_login_instructions(user, magic_link_url_fun, opts) do
          Logger.warning("could not send the log-in e-mail: #{inspect(reason)}")
        end
      end)

    :ok
  end

  @doc """
  Deletes the signed token with the given context.
  """
  def delete_user_session_token(token) do
    Repo.delete_all(from(UserToken, where: [token: ^token, context: "session"]))
    :ok
  end

  ## Google sign-in

  @doc """
  Finds, links or creates the user for a verified Google identity.

  `info` is a map: `%{google_uid: _, email: _, name: _, avatar_url: _, email_verified?: _}`.
  Returns `{:ok, user}` or `{:error, :email_not_verified | %Ecto.Changeset{}}`.
  """
  def get_or_register_google_user(%{email_verified?: true} = info) do
    cond do
      user = Repo.get_by(User, google_uid: info.google_uid) ->
        {:ok, user}

      user = get_user_by_email(info.email) ->
        link_google_account(user, info)

      true ->
        info
        |> User.google_registration_changeset()
        |> Repo.insert()
    end
  end

  def get_or_register_google_user(_info), do: {:error, :email_not_verified}

  # The account was never confirmed, so any password on it was set by someone who
  # did not prove they own the email. Google proved it; drop the password and
  # every existing session/token before handing the account over.
  defp link_google_account(%User{confirmed_at: nil} = user, info) do
    user
    |> User.google_changeset(info)
    |> User.confirm_changeset()
    |> Ecto.Changeset.change(hashed_password: nil)
    |> update_user_and_delete_all_tokens()
    |> case do
      {:ok, {user, _expired_tokens}} -> {:ok, user}
      {:error, _} = error -> error
    end
  end

  defp link_google_account(%User{} = user, info) do
    user
    |> User.google_changeset(info)
    |> Repo.update()
  end

  ## Token helper

  defp update_user_and_delete_all_tokens(changeset) do
    Repo.transact(fn ->
      with {:ok, user} <- Repo.update(changeset) do
        tokens_to_expire = Repo.all_by(UserToken, user_id: user.id)

        Repo.delete_all(from(t in UserToken, where: t.id in ^Enum.map(tokens_to_expire, & &1.id)))

        {:ok, {user, tokens_to_expire}}
      end
    end)
  end
end
