defmodule QuickSlips.SiteTest do
  # The setting is the whole application's, so these tests run one at a time.
  use ExUnit.Case, async: false

  alias QuickSlips.Site

  setup do
    previous = Application.fetch_env(:quickslips, :contact_email)

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:quickslips, :contact_email, value)
        :error -> Application.delete_env(:quickslips, :contact_email)
      end
    end)
  end

  describe "contact_email/0" do
    test "is the address that is set" do
      Application.put_env(:quickslips, :contact_email, "hello@example.org")

      assert Site.contact_email() == "hello@example.org"
    end

    test "has no spaces around it" do
      Application.put_env(:quickslips, :contact_email, "  hello@example.org \n")

      assert Site.contact_email() == "hello@example.org"
    end

    test "is nothing when nothing is set: no address is made up" do
      Application.put_env(:quickslips, :contact_email, nil)
      assert Site.contact_email() == nil

      Application.delete_env(:quickslips, :contact_email)
      assert Site.contact_email() == nil
    end

    test "is nothing for an empty or blank value, as an unset variable in a deployment may be" do
      for blank <- ["", "   ", "\n"] do
        Application.put_env(:quickslips, :contact_email, blank)
        assert Site.contact_email() == nil
      end
    end
  end
end
