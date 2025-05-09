defmodule XFsm.Machine do
  @moduledoc """
  Documentation for `XFsm.Machine`.
  """

  alias XFsm.Always
  alias XFsm.Event
  alias XFsm.State

  @enforce_keys [:context, :initial]
  defstruct [
    :initial,
    :state,
    :context,
    :actor,
    always: [],
    events: [],
    states: [],
    actions: %{},
    guards: %{}
  ]

  @type t :: %__MODULE__{
          initial: atom(),
          actor: nil | pid(),
          state: nil | atom(),
          context: XFsm.context(),
          always: [Always.t()],
          events: [Event.t()],
          states: [State.t()],
          guards: %{required(atom()) => fun()},
          actions: %{required(atom()) => fun()}
        }

  # TODO: raise an error
  # * if initial is set but there are no states defined
  # * when there are multiple global states
  @spec init(module(), keyword()) :: t()
  def init(module, opts \\ []) do
    opts = Keyword.validate!(opts, [:actor, :input, :actions, :guards])
    {guards, opts} = Keyword.pop(opts, :guards, %{})
    {actions, opts} = Keyword.pop(opts, :actions, %{})

    guards = module.__attr__(:guards) |> Map.merge(guards)
    actions = module.__attr__(:actions) |> Map.merge(actions)

    {globals, states} =
      module.__attr__(:states)
      |> Enum.split_with(&match?(%{name: :__global__}, &1))

    machine = %__MODULE__{
      actor: opts[:actor],
      states: states,
      guards: guards,
      actions: actions,
      initial: module.__attr__(:initial_state),
      context: module.__context__(%{input: opts[:input]}),
      events: Enum.map(globals, & &1.events) |> Enum.flat_map(& &1),
      always: Enum.map(globals, & &1.always) |> Enum.flat_map(& &1)
    }

    with state when state != nil <- machine.initial,
         %{} = state <- find_state(machine, state) do
      arg = %{self: self(machine)}

      enter_state(machine, state, nil, arg)
    else
      # INFO: maybe raise an error for missing initial state?!
      nil ->
        unless Enum.empty?(states) do
          raise ArgumentError, """
          An initial state has to be specified for the machine: #{inspect(module)}.
          """
        end

        machine
    end
  end

  defp self(%{actor: actor, state: state}) do
    %{pid: actor, state: state}
  end

  @spec transition(t(), XFsm.event()) :: t()
  def transition(
        %__MODULE__{state: state} = machine,
        %{type: type} = event
      )
      when state != nil and type != :* do
    %State{events: events} = find_state(machine, state)
    events = Enum.concat(events, machine.events)
    found = find_event(events, event, machine)

    case maybe_find_catch_all(found, events) do
      %Event{} = e ->
        e = %{e | target: e.target || state}
        arg = %{event: event, self: self(machine)}
        new_state = find_state(machine, e.target)

        enter_state(machine, new_state, e, arg)

      nil ->
        machine
    end
  end

  def transition(
        %__MODULE__{state: nil, events: events} = machine,
        %{type: type} = event
      )
      when type != :* do
    found = find_event(events, event, machine)

    case maybe_find_catch_all(found, events) do
      %Event{} = e ->
        e = %{e | target: nil}
        arg = %{actor: machine.actor, event: event}
        new_state = find_state(machine, e.target)

        enter_state(machine, new_state, e, arg)

      nil ->
        machine
    end
  end

  defp maybe_find_catch_all(%Event{} = e, _), do: e

  defp maybe_find_catch_all(nil, searchable_events) do
    Enum.find(searchable_events, &(&1.name == :*))
  end

  defp find_event(events, %{type: type} = e, machine) do
    events
    |> Enum.filter(&(&1.name == type))
    |> Enum.reduce_while(nil, fn %Event{guard: guard} = event, acc ->
      case allowed?(guard, e, machine) do
        true -> {:halt, event}
        false -> {:cont, acc}
      end
    end)
  end

  defp enter_state(
         machine,
         %State{} = new_state,
         event,
         arg
       ) do
    %{actions: actions, context: context, state: current} = machine
    current_state = find_state(machine, current)

    context = maybe_invoke_exits(current_state, new_state, arg, context, actions)

    context =
      case event do
        nil -> context
        %Event{action: fns} -> reduce_cbs(fns, context, arg, actions)
      end

    context = maybe_invoke_entry(current_state, new_state, arg, context, actions)

    machine = %{machine | state: new_state.name, context: context}

    new_state.always
    |> Enum.concat(machine.always)
    |> then(&apply_always(machine, &1, arg))
  end

  defp enter_state(
         %{state: nil} = machine,
         nil,
         event,
         arg
       ) do
    %{actions: actions, context: context} = machine

    context =
      case event do
        nil -> context
        %Event{action: fns} -> reduce_cbs(fns, context, arg, actions)
      end

    %{machine | context: context}
  end

  defp apply_always(machine, always, arg) do
    %{actions: actions, context: context} = machine

    matched = Enum.find(always, &allowed?(&1.guard, arg[:event], machine))

    case matched do
      %Always{target: t} = m when not is_nil(t) ->
        context =
          m.action
          |> List.wrap()
          |> reduce_cbs(context, arg, actions)

        machine = %{machine | context: context}

        case find_state(machine, t) do
          nil -> machine
          state -> enter_state(machine, state, nil, arg)
        end

      %Always{} = m ->
        context =
          m.action
          |> List.wrap()
          |> reduce_cbs(context, arg, actions)

        %{machine | context: context}

      _ ->
        machine
    end
  end

  defp allowed?(nil, _, _), do: true

  defp allowed?(guard, event, machine) do
    %{context: context, guards: guards} = machine
    self = self(machine)

    arg =
      case event do
        nil -> %{context: context, self: self}
        event -> %{context: context, event: event, self: self}
      end

    invoke(guard, arg, guards)
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
          params = maybe_invoke_params(params, arg)

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

  defp maybe_invoke_params(fun, arg) when is_function(fun, 1), do: fun.(arg)
  defp maybe_invoke_params(params, _arg), do: params

  defp maybe_invoke_exits(%{name: old} = o, %{name: new}, arg, context, actions)
       when old != new do
    reduce_cbs(o.exit, context, arg, actions)
  end

  defp maybe_invoke_exits(_old, _new, _arg, context, _actions), do: context

  defp maybe_invoke_entry(%{name: old}, %{name: new} = n, arg, context, actions)
       when old != new do
    reduce_cbs(n.entry, context, arg, actions)
  end

  defp maybe_invoke_entry(nil, %{} = n, arg, context, actions) do
    reduce_cbs(n.entry, context, arg, actions)
  end

  defp maybe_invoke_entry(_old, _new, _arg, context, _actions), do: context

  defmacro __using__(_) do
    quote do
      use XFsm.Builder
    end
  end
end
