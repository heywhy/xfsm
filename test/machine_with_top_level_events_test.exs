defmodule XFsm.MachineWithTopLevelEventsTest do
  use ExUnit.Case, async: true
  use XFsm.Actor
  use XFsm.Machine

  alias XFsm.Actor
  alias XFsm.Snapshot

  import XFsm.Actions

  context(%{count: 0})

  root do
    on :inc do
      action(assigns(%{count: &(&1.context.count + 1)}))
    end

    on :dec do
      action(assigns(%{count: &(&1.context.count - 1)}))
    end

    on :set do
      action(assigns(%{count: & &1.event.value}))
    end
  end

  setup do
    pid = start_supervised!({__MODULE__, []})

    [pid: pid]
  end

  test "increment count", %{pid: pid} do
    :ok = Actor.send(pid, %{type: :inc})

    assert snapshot = Actor.snapshot(pid)
    assert %Snapshot{state: nil, context: %{count: 1}} = snapshot
  end

  test "decrement count", %{pid: pid} do
    :ok = Actor.send(pid, %{type: :dec})

    assert snapshot = Actor.snapshot(pid)
    assert %Snapshot{state: nil, context: %{count: -1}} = snapshot
  end

  test "set count", %{pid: pid} do
    :ok = Actor.send(pid, %{type: :set, value: 10})

    assert snapshot = Actor.snapshot(pid)
    assert %Snapshot{state: nil, context: %{count: 10}} = snapshot
  end

  test "unknown event is ignored", %{pid: pid} do
    assert snapshot = Actor.snapshot(pid)
    assert %Snapshot{state: nil, context: %{count: 0}} = snapshot

    :ok = Actor.send(pid, %{type: :unknown, value: 10})

    assert snapshot = Actor.snapshot(pid)
    assert %Snapshot{state: nil, context: %{count: 0}} = snapshot
  end
end
