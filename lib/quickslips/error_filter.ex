defmodule QuickSlips.ErrorFilter do
  @moduledoc """
  Decides what ErrorTracker may keep from the context of an error.

  The context of a failed request, LiveView event or job can hold passwords, one-time log-in tokens and
  whatever people typed into a bill. None of that is stored; only where and how the error happened is.
  """
  @behaviour ErrorTracker.Filter

  # What visitors typed (request, LiveView event and job arguments) and the query string, which can carry
  # an OAuth code.
  @dropped ~w(request.params request.query live_view.params live_view.event_params job.args)

  @impl true
  def sanitize(context) do
    context
    |> Map.drop(@dropped)
    |> keep_only_user_agent()
    |> clean_url("request.path")
    |> clean_url("live_view.uri")
  end

  # Of all the headers (ErrorTracker already redacts cookies) only the browser's name is useful.
  defp keep_only_user_agent(%{"request.headers" => headers} = context) when is_map(headers) do
    Map.put(context, "request.headers", Map.take(headers, ["user-agent"]))
  end

  defp keep_only_user_agent(context), do: context

  # Drops a query string and hides the one-time token of an e-mail log-in or confirm-email link.
  defp clean_url(context, key) do
    case context do
      %{^key => url} when is_binary(url) ->
        url = url |> String.split(["?", "#"], parts: 2) |> hd()

        Map.put(
          context,
          key,
          Regex.replace(~r{(/users/(?:log-in|settings/confirm-email)/)[^/\s]+}, url, "\\1:token")
        )

      _ ->
        context
    end
  end
end
