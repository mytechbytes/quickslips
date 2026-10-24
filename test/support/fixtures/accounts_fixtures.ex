defmodule QuickSlips.AccountsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `QuickSlips.Accounts` context.
  """

  import Ecto.Query

  alias QuickSlips.Accounts
  alias QuickSlips.Accounts.Scope

  def unique_user_email, do: "user#{System.unique_integer()}@example.com"
  # Must satisfy the rules in User.password_changeset/3: length, one lower case,
  # one upper case and one digit or punctuation character.
  def valid_user_password, do: "Hello world!"

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password(),
      password_confirmation: valid_user_password()
    })
  end

  def unconfirmed_user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> Accounts.register_user()

    user
  end

  # Users registered with a password cannot be confirmed through a bare magic
  # link (see Accounts.login_user_by_magic_link/1), so confirm them directly.
  def user_fixture(attrs \\ %{}) do
    attrs
    |> unconfirmed_user_fixture()
    |> Accounts.User.confirm_changeset()
    |> QuickSlips.Repo.update!()
  end

  # An unconfirmed user with no password, the shape a social login would create.
  def unconfirmed_passwordless_user_fixture do
    QuickSlips.Repo.insert!(%Accounts.User{email: unique_user_email()})
  end

  def user_scope_fixture do
    user = user_fixture()
    user_scope_fixture(user)
  end

  def user_scope_fixture(user) do
    Scope.for_user(user)
  end

  def set_password(user) do
    {:ok, {user, _expired_tokens}} =
      Accounts.update_user_password(user, %{password: valid_user_password()})

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end

  def override_token_authenticated_at(token, authenticated_at) when is_binary(token) do
    QuickSlips.Repo.update_all(
      from(t in Accounts.UserToken,
        where: t.token == ^token
      ),
      set: [authenticated_at: authenticated_at]
    )
  end

  def generate_user_magic_link_token(user) do
    {encoded_token, user_token} = Accounts.UserToken.build_email_token(user, "login")
    QuickSlips.Repo.insert!(user_token)
    {encoded_token, user_token.token}
  end

  def offset_user_token(token, amount_to_add, unit) do
    dt = DateTime.add(DateTime.utc_now(:second), amount_to_add, unit)

    QuickSlips.Repo.update_all(
      from(ut in Accounts.UserToken, where: ut.token == ^token),
      set: [inserted_at: dt, authenticated_at: dt]
    )
  end
end
