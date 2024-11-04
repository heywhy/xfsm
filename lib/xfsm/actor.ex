defmodule XFsm.Actor do
  @moduledoc """
  Documentation for `XFsm.Actor`.
  """

  alias XFsm.Machine
  alias XFsm.Snapshot

  @spec snapshot(GenServer.server()) :: Snapshot.t()
  def snapshot(pid), do: GenServer.call(pid, :snapshot)

  @spec send(GenServer.server(), XFsm.event()) :: :ok
  def send(pid, event), do: GenServer.cast(pid, {:send, event})

  defmacro __using__(_opts) do
    quote do
      use GenServer

      @spec start_link(keyword()) :: GenServer.on_start()
      def start_link(opts \\ []) do
        actor_opts = Keyword.take(opts, ~w[debug hibernate_after name spawn_opt timeout]a)

        GenServer.start_link(__MODULE__, opts, actor_opts)
      end

      @impl GenServer
      def init(opts) do
        opts = Keyword.put(opts, :actor, self())

        {:ok, %{machine: Machine.init(__MODULE__, opts)}}
      end

      @impl GenServer
      def handle_call(:snapshot, _from, %{machine: machine} = state) do
        snapshot = %Snapshot{state: machine.state, context: machine.context}

        {:reply, snapshot, state}
      end

      @impl GenServer
      def handle_cast({:send, event}, %{machine: machine} = state) do
        machine = Machine.transition(machine, event)

        {:noreply, %{state | machine: machine}}
      end
    end
  end
end
