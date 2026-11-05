defmodule QuickSlips.ErrorFilterTest do
  use ExUnit.Case, async: true

  alias QuickSlips.ErrorFilter

  test "drops what visitors typed, the query string and job arguments" do
    context = %{
      "request.method" => "POST",
      "request.params" => %{"user" => %{"password" => "hunter2"}},
      "request.query" => "code=abc&state=xyz",
      "live_view.params" => %{"token" => "secret"},
      "live_view.event_params" => %{"user" => %{"password" => "hunter2"}},
      "job.args" => %{"rows" => [%{"name" => "A. Person"}]}
    }

    assert ErrorFilter.sanitize(context) == %{"request.method" => "POST"}
  end

  test "keeps only the user agent of the headers" do
    headers = %{
      "user-agent" => "curl/8",
      "x-csrf-token" => "abc",
      "referer" => "https://quickslips.example.com/users/log-in/TOKEN"
    }

    assert ErrorFilter.sanitize(%{"request.headers" => headers}) ==
             %{"request.headers" => %{"user-agent" => "curl/8"}}
  end

  test "hides the one-time token of an e-mail link" do
    assert ErrorFilter.sanitize(%{"request.path" => "/users/log-in/AbC123"}) ==
             %{"request.path" => "/users/log-in/:token"}

    assert ErrorFilter.sanitize(%{"request.path" => "/users/settings/confirm-email/AbC123"}) ==
             %{"request.path" => "/users/settings/confirm-email/:token"}

    assert ErrorFilter.sanitize(%{
             "live_view.uri" =>
               "https://quickslips.example.com/users/log-in/AbC123?mode=password#top"
           }) == %{"live_view.uri" => "https://quickslips.example.com/users/log-in/:token"}
  end

  test "leaves other paths alone" do
    assert ErrorFilter.sanitize(%{"request.path" => "/fuel-bill", "request.ip" => "203.0.113.9"}) ==
             %{"request.path" => "/fuel-bill", "request.ip" => "203.0.113.9"}
  end
end
