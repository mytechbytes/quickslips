defmodule QuickSlips.TaskHelpers do
  @moduledoc """
  For tests of what happens in a task that the code started and does not wait for (`QuickSlips.TaskSupervisor`:
  the e-mails that follow a message of the contact form).
  """
  import ExUnit.Assertions, only: [flunk: 1]

  @doc """
  Waits until every task of the supervisor has finished, however long that takes (up to five seconds), with no
  guess and no sleep.
  """
  def wait_for_tasks do
    for pid <- Task.Supervisor.children(QuickSlips.TaskSupervisor) do
      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
      after
        5_000 -> flunk("a task did not finish in five seconds")
      end
    end

    :ok
  end
end
