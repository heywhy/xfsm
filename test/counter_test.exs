defmodule XFsm.CounterTest do
  use ExUnit.Case, async: true
  use XFsm.Actor
  use XFsm.Machine

  alias XFsm.Actor
  alias XFsm.Snapshot

  import XFsm.Actions

  context(%{count: 0})

  on :inc do
    action(assigns(%{count: &(&1.context.count + 1)}))
  end

  on :dec do
    action(assigns(%{count: &(&1.context.count - 1)}))
  end

  on :set do
    action(assigns(%{count: & &1.event.value}))
  end

  setup do
    pid = start_supervised!({__MODULE__, []})

    [pid: pid]
  end

  test "increment count", %{pid: pid} do
    test_pid = self()

    Actor.subscribe(pid, &send(test_pid, {:changed, &1}))

    :ok = Actor.send(pid, %{type: :inc})

    assert_receive {:changed, %Snapshot{state: nil, context: %{count: 1}}}
  end

  test "decrement count", %{pid: pid} do
    test_pid = self()

    Actor.subscribe(pid, &send(test_pid, {:changed, &1}))

    :ok = Actor.send(pid, %{type: :dec})

    assert_receive {:changed, %Snapshot{state: nil, context: %{count: -1}}}
  end

  test "set count", %{pid: pid} do
    test_pid = self()

    Actor.subscribe(pid, &send(test_pid, {:changed, &1}))

    :ok = Actor.send(pid, %{type: :set, value: 10})

    assert_receive {:changed, %Snapshot{state: nil, context: %{count: 10}}}
  end
end
