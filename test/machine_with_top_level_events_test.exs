defmodule XFsm.MachineWithTopLevelEventsTest do
  use ExUnit.Case, async: true
  use XFsm.Actor
  use XFsm.Machine

  alias XFsm.Actor
  alias XFsm.Snapshot

  context %{count: 0}

  root do
    on :inc do
      action :assign, &inc/1
    end

    on :dec do
      action :assign, &dec/1
    end

    on :set do
      action :assign, &set/1
    end
  end

  def inc(%{context: context}), do: %{count: context.count + 1}
  def dec(%{context: context}), do: %{count: context.count - 1}
  def set(%{event: event}), do: %{count: event.value}

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
