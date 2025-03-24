defmodule XFsm.Actions do
  @moduledoc """
  Documentation for `XFsm.Actions`.
  """

  alias XFsm.Actor
  alias XFsm.Timers

  @spec send_event(XFsm.action_arg(), map() | fun(), keyword()) :: XFsm.context()
  def send_event(arg, event, opts \\ [])

  def send_event(%{actor: pid, context: context}, %{type: _} = event, opts) when is_pid(pid) do
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

  def send_event(arg, fun, opts) when is_function(fun, 1) do
    send_event(arg, fun.(arg), opts)
  end

  @spec cancel(XFsm.action_arg(), term()) :: XFsm.context()
  def cancel(%{context: context}, id) do
    ref = Timers.remove(id)

    case ref do
      nil -> :ok
      ref when is_reference(ref) -> Process.cancel_timer(ref)
    end

    context
  end

  @spec assigns(XFsm.action_arg(), map()) :: XFsm.context()
  def assigns(%{context: context} = arg, %{} = attrs) do
    changes =
      Enum.reduce(attrs, %{}, fn
        {key, fun}, changes when is_function(fun) ->
          Map.put(changes, key, fun.(arg))

        {key, value}, changes ->
          Map.put(changes, key, value)
      end)

    Map.merge(context, changes)
  end
end
