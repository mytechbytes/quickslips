defmodule QuickSlips.AuthLimits do
  @moduledoc """
  The brakes of the log-in and sign-up pages, on top of `QuickSlips.RateLimit` (which says how many; the numbers are
  its rules).

  Three things are being kept from happening:

    * **Guessing passwords.** Every wrong password is counted for the address of the visitor (`login_ip`) and for the
      e-mail address that was typed (`login_email`). Past the limit of either, the log-in is turned away *before*
      the password is looked at, so a script gets nothing more out of trying. The limit of an address is higher than
      that of an account because many people can share an address. Someone who locks an account this way only
      locks the password: the link by e-mail, Google and Microsoft still work.
    * **Trying passwords with a script.** After a few wrong passwords from one address (`login_captcha`) the log-in asks
      for the Turnstile check as well. Until then it does not: a person who knows their password never meets it.
    * **Sending e-mail at somebody.** The sign-up and the "e-mail me a link" forms send an e-mail for whatever address is
      typed. They are counted per visitor address, per address typed and in all (`mail_ip`, `mail_email`, `mail_all`),
      so nobody can fill a mailbox, and the SMTP account of the site is not used up by a script.

  A counter is only as good as its key. The visitor's address comes from `QuickSlips.ClientIp.key/1`, and an e-mail
  address is counted by a hash of it, so that the counters hold no address.
  """
  alias QuickSlips.RateLimit

  @doc """
  Counts one e-mail that is about to be sent for `email`, asked from `ip_key`. `:ok`, or `{:error, {:slow_down,
  seconds}}` when one of the three limits is over. A limit that turns the request away does not count it in the next,
  so a visitor who is over their own limit does not use up the site's.
  """
  def check_mail(ip_key, email) do
    with :ok <- RateLimit.hit(:mail_ip, ip_key),
         :ok <- RateLimit.hit(:mail_email, email_key(email)),
         :ok <- RateLimit.hit(:mail_all, :all) do
      :ok
    else
      {:error, seconds} -> {:error, {:slow_down, seconds}}
    end
  end

  @doc "Whether a log-in with a password may be tried now: `:ok`, or `{:error, {:slow_down, seconds}}`. Does not count."
  def check_login(ip_key, email) do
    cond do
      RateLimit.full?(:login_ip, ip_key) ->
        {:error, {:slow_down, RateLimit.retry_after(:login_ip)}}

      RateLimit.full?(:login_email, email_key(email)) ->
        {:error, {:slow_down, RateLimit.retry_after(:login_email)}}

      true ->
        :ok
    end
  end

  @doc "Counts a wrong password (or an e-mail address with no account: the page says the same of both)."
  def record_login_failure(ip_key, email) do
    RateLimit.hit(:login_ip, ip_key)
    RateLimit.hit(:login_email, email_key(email))
    RateLimit.hit(:login_captcha, ip_key)
    :ok
  end

  @doc """
  A right password: the wrong ones of that account are forgotten, so that somebody who fumbled their own password a
  few times is not kept out of it. The wrong passwords of the address are not: otherwise a script could log in to an
  account of its own between its guesses and never be asked for the check.
  """
  def clear_login_failures(email), do: RateLimit.forget(:login_email, email_key(email))

  @doc "Whether the address has been wrong often enough that the next log-in has to pass the Turnstile check."
  def captcha_required?(ip_key), do: RateLimit.full?(:login_captcha, ip_key)

  # The counter is kept under a hash of the address, so that the table of counters holds no address.
  defp email_key(email) do
    normal = email |> to_string() |> String.trim() |> String.downcase()
    :crypto.hash(:sha256, normal) |> Base.encode16(case: :lower)
  end
end
