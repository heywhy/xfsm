defmodule XFsm.Actions do
  @moduledoc """
  Documentation for `XFsm.Actions`.
  """

  alias XFsm.Actor

  @spec send_event(XFsm.action_arg(), map() | fun(), keyword()) :: map()
  def send_event(arg, event, opts \\ [])

  def send_event(%{actor: pid, context: context}, %{type: _} = event, opts) when is_pid(pid) do
    case opts[:delay] do
      nil ->
        Actor.send(pid, event)

      delay when is_integer(delay) ->
        :erlang.send_after(delay, pid, {:"$gen_cast", {:send, event}})
    end

    context
  end

  def send_event(arg, fun, opts) when is_function(fun, 1) do
    send_event(arg, fun.(arg), opts)
  end

  @spec assigns(XFsm.action_arg(), map()) :: map()
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
