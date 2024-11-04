defmodule XFsm.Machine do
  @moduledoc false

  alias XFsm.Event
  alias XFsm.State

  @enforce_keys [:context, :initial]
  defstruct [:initial, :state, :context, :actor, states: [], actions: %{}, guards: %{}]

  @type t :: %__MODULE__{
          initial: atom(),
          actor: nil | pid(),
          state: nil | atom(),
          context: nil | map(),
          states: [State.t()],
          guards: %{required(atom()) => fun()},
          actions: %{required(atom()) => fun()}
        }

  @spec init(module(), keyword()) :: t()
  def init(module, opts \\ []) do
    opts =
      opts
      |> Keyword.validate!([:actor, :input])
      |> Map.new()

    machine =
      struct!(__MODULE__,
        actor: opts[:actor],
        context: module.__context__(opts),
        states: module.__attr__(:states),
        guards: module.__attr__(:guards),
        actions: module.__attr__(:actions),
        initial: module.__attr__(:initial_state)
      )

    with state when state != nil <- machine.initial,
         %{} = state <- find_state(machine, state) do
      arg = %{
        actor: machine.actor,
        context: machine.context
      }

      enter_state(machine, state, nil, arg)
    else
      nil -> machine
    end
  end

  @spec transition(t(), XFsm.event()) :: t()
  def transition(
        %__MODULE__{actions: actions, actor: actor, context: context, state: state} = machine,
        %{} = event
      )
      when state != nil do
    arg = %{actor: actor, event: event}
    %State{events: events} = find_state(machine, state)

    case find_event(events, event, machine) do
      %Event{action: fns, target: target} = event ->
        case find_state(machine, target) do
          nil -> %{machine | context: reduce_cbs(fns, context, arg, actions)}
          state -> enter_state(machine, state, event, arg)
        end

      nil ->
        machine
    end
  end

  defp find_event(events, %{type: type} = e, %{context: context, guards: guards}) do
    events
    |> Enum.filter(&(&1.name == type))
    |> Enum.reduce_while(nil, fn
      %Event{guard: nil} = event, _acc ->
        {:halt, event}

      %Event{guard: guard} = event, acc ->
        arg = %{context: context, event: e}

        case invoke(guard, arg, guards) do
          true -> {:halt, event}
          false -> {:cont, acc}
        end
    end)
  end

  defp enter_state(
         %{actions: actions, context: context, state: current, states: states} = machine,
         %{name: state, entry: entry_fns},
         event,
         arg
       ) do
    current_state = Enum.find(states, &(&1.name == current))

    context =
      case current_state do
        nil -> context
        %State{exit: fns} -> reduce_cbs(fns, context, arg, actions)
      end

    context =
      case event do
        nil -> context
        %Event{action: fns} -> reduce_cbs(fns, context, arg, actions)
      end

    context = reduce_cbs(entry_fns, context, arg, actions)

    %{machine | state: state, context: context}
  end

  defp find_state(%{states: states}, state), do: Enum.find(states, &(&1.name == state))

  defp reduce_cbs(nil, context, _arg, _actions), do: context

  defp reduce_cbs(fun, context, arg, actions)
       when is_atom(fun) or is_function(fun) or is_map(fun) do
    reduce_cbs([fun], context, arg, actions)
  end

  defp reduce_cbs(fns, context, arg, actions) when is_list(fns) do
    Enum.reduce(fns, context, fn fun, context ->
      arg = Map.put(arg, :context, context)

      invoke(fun, arg, actions)
    end)
  end

  defp invoke(fun, arg, actions) do
    {fun, arg, params} =
      case fun do
        fun when is_atom(fun) ->
          {Map.fetch!(actions, fun), arg, nil}

        %{method: fun, params: params} when is_atom(fun) ->
          {Map.fetch!(actions, fun), arg, params}

        fun ->
          {fun, arg, nil}
      end

    cond do
      is_function(fun, 2) -> fun.(arg, params)
      is_function(fun, 1) -> fun.(arg)
      true -> fun.()
    end
  end

  defmacro __using__(_) do
    quote do
      use XFsm.Builder
    end
  end
end
