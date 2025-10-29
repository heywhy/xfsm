defmodule XFsm.MachineTest do
  use ExUnit.Case, async: true
  use XFsm.Machine

  alias XFsm.Machine

  defmodule MissingInitialState do
    use XFsm.Machine

    state :one do
    end

    state :two do
    end
  end

  initial(:active)
  context(%{count: 0})

  state :active do
    entry(:assign, &increment/1)
    exit(:noop)

    on :toggle do
      guard(:toggle?)
      target(:inactive)
    end
  end

  state :inactive do
    on :toggle do
      guard(:toggle?)
      target(:active)
    end
  end

  def toggle?(_), do: true

  def noop(_), do: nil
  def increment(%{context: context}), do: %{count: context.count + 1}

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

  # TODO: test the transition method
  test "raise an error for missing initial state" do
    assert_raise ArgumentError,
                 """
                 An initial state has to be specified for the machine: XFsm.MachineTest.MissingInitialState.
                 """,
                 fn ->
                   Machine.init(MissingInitialState)
                 end
  end

  # TODO: test overriding actions & guards.
  test "override default actions" do
    pid = self()
    actions = %{noop: fn _ -> send(pid, :called) end}

    machine = Machine.init(__MODULE__, actions: actions)

    assert %{state: :inactive, context: %{count: 1}} =
             Machine.transition(machine, %{type: :toggle})

    assert_receive :called
  end

  test "override default guards" do
    pid = self()
    guards = %{toggle?: fn _ -> send(pid, :called) == :called end}

    machine = Machine.init(__MODULE__, guards: guards)

    assert %{state: :inactive, context: %{count: 1}} =
             Machine.transition(machine, %{type: :toggle})

    assert_receive :called
  end
end
