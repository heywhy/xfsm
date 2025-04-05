defmodule XFsm.ActorTest do
  use ExUnit.Case, async: true
  use XFsm.Actor
  use XFsm.Machine

  alias XFsm.Actor
  alias XFsm.Snapshot

  initial(:off)

  state :off do
    on :toggle do
      target(:on)
    end
  end

  state :on do
    on :toggle do
      target(:off)
    end
  end

  setup do
    pid = start_supervised!({__MODULE__, []})

    [pid: pid]
  end

  test "subscribe to an actor", %{pid: pid} do
    test_pid = self()
    ref = Actor.subscribe(pid, &send(test_pid, {:changed, &1}))

    assert is_reference(ref)
    assert :ok = Actor.send(pid, %{type: :toggle})
    assert_receive {:changed, %Snapshot{state: :on}}
  end

  test "unsubscribe from an actor", %{pid: pid} do
    test_pid = self()
    ref = Actor.subscribe(pid, &send(test_pid, {:changed, &1}))

    assert is_reference(ref)
    assert :ok = Actor.send(pid, %{type: :toggle})
    assert_receive {:changed, %Snapshot{state: :on}}

    assert :ok = Actor.unsubscribe(pid, ref)
    assert :ok = Actor.send(pid, %{type: :toggle})
    refute_receive {:changed, %Snapshot{state: :off}}
  end
end
