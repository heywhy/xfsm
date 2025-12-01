defmodule XFsm.Timers do
  @moduledoc """
  Documentation for `XFsm.Timers`.
  """
  use GenServer

  @spec start_link(keyword()) :: Agent.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__, hibernate_after: 5_000)
  end

  @spec get(term()) :: nil | reference()
  def get(id) do
    case :ets.lookup(__MODULE__, id) do
      [] -> nil
      [{^id, ref}] -> ref
    end
  end

  @spec remove(term()) :: nil | reference()
  def remove(id) do
    GenServer.call(__MODULE__, {:remove, id})
  end

  @spec add(term(), reference()) :: :ok
  def add(id, ref) when is_reference(ref) do
    GenServer.call(__MODULE__, {:add, id, ref})
  end

  @impl GenServer
  def init([]) do
    table = :ets.new(__MODULE__, [:named_table, :protected, :set, read_concurrency: true])

    {:ok, table: table}
  end

  @impl GenServer
  def handle_call({:add, id, ref}, _from, state) do
    true = :ets.insert(__MODULE__, {id, ref})

    {:reply, :ok, state}
  end

  def handle_call({:remove, id}, _from, state) do
    value = get(id)
    true = :ets.delete(__MODULE__, id)

    {:reply, value, state}
  end
end
