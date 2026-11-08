defmodule QuickSlips.Contact.Topic do
  @moduledoc """
  The names of the kinds of message (`QuickSlips.Contact.Message.topics/0`), in the two voices that use them: the
  visitor's, in the language of the page (the form and the confirmation e-mail), and the owner's, in English (the
  e-mail to the owner and the page of messages). The words of the visitor are Gettext messages, so each is written
  here once and the page and the e-mail cannot drift apart.
  """
  use Gettext, backend: QuickSlipsWeb.Gettext

  @doc "What the kind is called to the visitor."
  def label(:change), do: gettext("Ask for a change")
  def label(:feedback), do: gettext("Give feedback")
  def label(:problem), do: gettext("Report a problem")
  def label(:complaint), do: gettext("Complaint or dispute")
  def label(:other), do: gettext("Something else")

  @doc "What the kind is for, in a line, to the visitor."
  def help(:change), do: gettext("A new template, a missing field, another language or country.")
  def help(:feedback), do: gettext("What works well, and what could be better.")
  def help(:problem), do: gettext("Something is broken, wrong or confusing.")
  def help(:complaint), do: gettext("A disagreement about a document, an account or your data.")
  def help(:other), do: gettext("Anything that does not fit the other kinds.")

  @doc "What the kind is called to the owner, who reads English."
  def name(:change), do: "Change request"
  def name(:feedback), do: "Feedback"
  def name(:problem), do: "Problem report"
  def name(:complaint), do: "Complaint or dispute"
  def name(:other), do: "Other"
end
