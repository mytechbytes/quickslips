defmodule QuickSlips.ErrorTrackingTest do
  use QuickSlips.DataCase

  alias QuickSlips.Repo

  test "an error is stored without what the visitor typed" do
    context = %{
      "request.method" => "POST",
      "request.path" => "/users/log-in/AbC123",
      "request.params" => %{"user" => %{"password" => "hunter2"}}
    }

    assert %ErrorTracker.Occurrence{} =
             ErrorTracker.report(%RuntimeError{message: "boom"}, [], context)

    occurrence = Repo.one!(ErrorTracker.Occurrence)

    assert occurrence.context == %{
             "request.method" => "POST",
             "request.path" => "/users/log-in/:token"
           }
  end

  test "a missing page is not stored" do
    assert :noop = ErrorTracker.report(%QuickSlipsWeb.NotFoundError{}, [])
    assert Repo.aggregate(ErrorTracker.Error, :count) == 0
  end
end
