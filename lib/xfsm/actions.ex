defmodule XFsm.Actions do
  @moduledoc """
  Documentation for `XFsm.Actions`.
  """

  alias XFsm.Actor
  alias XFsm.Timers

  @spec send_event(XFsm.action_arg(), map() | fun() | keyword()) :: XFsm.context()
  def send_event(arg, %{type: _} = event) do
    do_send_event(arg, event, [])
  end

  def send_event(arg, opts) when is_list(opts) do
    {event, opts} = Keyword.pop!(opts, :event)

    do_send_event(arg, event, opts)
  end

  def send_event(arg, fun) when is_function(fun, 1) do
    send_event(arg, fun.(arg))
  end

  defp do_send_event(
         %{self: %{pid: pid}, context: context},
         %{type: _} = event,
         opts
       )
       when is_pid(pid) do
    case opts[:delay] do
      nil ->
        Actor.send(pid, event)

      delay when is_integer(delay) ->
        # INFO: maybe tag id with the machine module?
        id = opts[:id]
        ref = Process.send_after(pid, {:"$gen_cast", {:send, event}}, delay)

        Timers.add(id, ref)
    end

    context
  end

  @spec cancel(XFsm.action_arg(), term()) :: XFsm.context()
  def cancel(arg, fun) when is_function(fun, 1) do
    cancel(arg, fun.(arg))
  end

  def cancel(%{context: context}, id) do
    case Timers.remove(id) do
      nil -> :ok
      ref when is_reference(ref) -> Process.cancel_timer(ref)
    end

    context
  end

  @spec assign(XFsm.action_arg(), map() | (XFsm.action_arg() -> map())) ::
          {:update, XFsm.context()}
  def assign(arg, fun) when is_function(fun, 1) do
    assign(arg, fun.(arg))
  end

  def assign(%{context: context} = arg, %{} = attrs) do
    changes =
      Enum.reduce(attrs, %{}, fn
        {key, fun}, changes when is_function(fun) ->
          Map.put(changes, key, fun.(arg))

        {key, value}, changes ->
          Map.put(changes, key, value)
      end)

    {:update, Map.merge(context, changes)}
  end

  def assigns(arg, attrs), do: assign(arg, attrs)
end
