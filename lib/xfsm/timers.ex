defmodule XFsm.Timers do
  @moduledoc """
  Documentation for `XFsm.Timers`.
  """
  use Agent

  @spec remove(term()) :: nil | reference()
  def remove(id) do
    Agent.get_and_update(__MODULE__, &{&1[id], Map.delete(&1, id)})
  end

  @spec add(term(), reference()) :: :ok
  def add(id, ref) when is_reference(ref) do
    Agent.update(XFsm.Timers, &Map.put(&1, id, ref))
  end

  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(_opts) do
    Agent.start_link(fn -> %{} end, name: __MODULE__, hibernate_after: 5_000)
  end
end
