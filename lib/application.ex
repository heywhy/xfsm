defmodule XFsm.Application do
  @moduledoc """
  Documentation for `XFsm.Application`.
  """
  use Application

  @impl true
  def start(_, _) do
    children = [
      %{
        id: Agent,
        start: {Agent, :start_link, [fn -> %{} end, [name: XFsm.Timers, hibernate_after: 5_000]]}
      }
    ]

    Supervisor.start_link(children, name: __MODULE__, strategy: :one_for_one)
  end
end
