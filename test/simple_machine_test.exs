defmodule XFsm.SimpleMachineTest do
  use ExUnit.Case, async: true
  use XFsm.Machine

  alias XFsm.Machine

  import XFsm.Actions

  initial(:active)
  context(%{count: 0})

  state :active do
    entry(
      assigns(%{
        count: &(&1.context.count + 1)
      })
    )

    on :toggle do
      target(:inactive)
    end
  end

  state :inactive do
    on :toggle do
      target(:active)
    end
  end

  test "init machine" do
    assert %{state: :active, context: context} = Machine.init(__MODULE__)
    assert %{count: 1} = context
  end

  test "transition to new state" do
    machine = Machine.init(__MODULE__)

    assert %{state: :inactive, context: %{count: 1}} =
             Machine.transition(machine, %{type: :toggle})
  end

  test "ignore transition if event is unknown" do
    machine = Machine.init(__MODULE__)

    assert %{state: :active, context: %{count: 1}} =
             Machine.transition(machine, %{type: :unknown})
  end
end
