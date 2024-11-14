defmodule XFsm.Application do
  @moduledoc """
  Documentation for `XFsm.Application`.
  """
  use Application

  alias XFsm.Timers

  @impl true
  def start(_, _) do
    children = [Timers]

    Supervisor.start_link(children, name: __MODULE__, strategy: :one_for_one)
  end
end
