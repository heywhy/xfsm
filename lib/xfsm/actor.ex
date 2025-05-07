defmodule XFsm.Actor do
  @moduledoc """
  Documentation for `XFsm.Actor`.
  """
  use GenServer

  alias XFsm.Machine
  alias XFsm.Snapshot

  @spec snapshot(GenServer.server()) :: Snapshot.t()
  def snapshot(pid), do: GenServer.call(pid, :snapshot)

  @spec send(GenServer.server(), XFsm.event()) :: :ok
  def send(pid, event), do: GenServer.cast(pid, {:send, event})

  @spec subscribe(pid(), fun()) :: reference()
  def subscribe(pid, fun) when is_function(fun, 1) do
    GenServer.call(pid, {:subscribe, fun})
  end

  @spec unsubscribe(pid(), reference()) :: :ok
  def unsubscribe(pid, ref) when is_reference(ref) do
    GenServer.call(pid, {:unsubscribe, ref})
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    actor_opts = Keyword.take(opts, ~w[debug hibernate_after name spawn_opt timeout]a)

    GenServer.start_link(__MODULE__, opts, actor_opts)
  end

  @impl GenServer
  def init(opts) do
    {machine, opts} = Keyword.pop!(opts, :machine)
    opts = Keyword.put(opts, :actor, self())

    state = %{
      subs: %{},
      machine: Machine.init(machine, opts)
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:snapshot, _from, %{machine: machine} = state) do
    snapshot = snapshot_from_machine(machine)

    {:reply, snapshot, state}
  end

  def handle_call({:subscribe, fun}, _from, %{subs: subs, machine: machine} = state) do
    ref = make_ref()
    subs = Map.put(subs, ref, fun)
    snapshot = snapshot_from_machine(machine)

    Process.spawn(fn -> fun.(snapshot) end, [])

    {:reply, ref, %{state | subs: subs}}
  end

  def handle_call({:unsubscribe, ref}, _from, %{subs: subs} = state) do
    subs = Map.delete(subs, ref)

    {:reply, :ok, %{state | subs: subs}}
  end

  @impl GenServer
  def handle_cast({:send, event}, %{machine: machine} = state) do
    machine = Machine.transition(machine, event)

    :ok = Process.send(self(), :notify_subs, [])

    {:noreply, %{state | machine: machine}}
  end

  # INFO: find an efficient approach to pass snapshot around assuming
  # an actor state/context is too large.
  @impl GenServer
  def handle_info(:notify_subs, state) do
    %{machine: machine, subs: subs} = state
    snapshot = snapshot_from_machine(machine)

    for {_, fun} <- subs do
      Process.spawn(fn -> fun.(snapshot) end, [])
    end

    {:noreply, state}
  end

  defp snapshot_from_machine(machine) do
    %Snapshot{state: machine.state, context: machine.context}
  end

  defmacro __using__(spec \\ []) do
    spec =
      spec
      |> Keyword.validate!(~w[restart shutdown modules significant]a)
      |> Enum.into(%{})
      |> Macro.escape()

    quote do
      @spec start_link(keyword()) :: GenServer.on_start()
      def start_link(opts \\ []) do
        opts = Keyword.merge(opts, machine: __MODULE__)

        XFsm.Actor.start_link(opts)
      end

      @spec child_spec(keyword()) :: Supervisor.child_spec()
      def child_spec(opts) do
        default = %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :worker
        }

        Map.merge(default, unquote(spec))
      end
    end
  end
end
