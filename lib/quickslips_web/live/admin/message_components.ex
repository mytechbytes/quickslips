defmodule QuickSlipsWeb.Admin.MessageComponents do
  @moduledoc """
  Small pieces that the pages of the messages (`/admin/messages`) share: the badges for the status and the kind of a
  message, and the way a time is written. The pages for the owner are in English, like the e-mails to the owner.
  """
  use QuickSlipsWeb, :html

  alias QuickSlips.Contact.Topic

  attr :status, :atom, required: true

  def status_badge(assigns) do
    ~H"""
    <.badge tone={status_tone(@status)}>{status_label(@status)}</.badge>
    """
  end

  defp status_tone(:new), do: :primary
  defp status_tone(:read), do: :neutral
  defp status_tone(:resolved), do: :success

  @doc "What a status is called."
  def status_label(:new), do: "New"
  def status_label(:read), do: "Read"
  def status_label(:resolved), do: "Resolved"

  attr :topic, :atom, required: true

  def topic_badge(assigns) do
    ~H"""
    <.badge tone={:info}>{Topic.name(@topic)}</.badge>
    """
  end

  @doc "A time as people write it, in UTC like the e-mails: `8 Nov 2026, 09:58 UTC`."
  def time(%DateTime{} = time), do: Calendar.strftime(time, "%-d %b %Y, %H:%M UTC")
  def time(nil), do: nil
end
