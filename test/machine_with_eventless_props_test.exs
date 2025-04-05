defmodule XFsm.MachineWithEventlessPropsTest do
  use ExUnit.Case, async: true
  use XFsm.Actor
  use XFsm.Machine

  alias XFsm.Machine

  import XFsm.Actions

  initial(:lukewarm)
  context(%{temp: 80})

  state :lukewarm do
    on :boil do
      target(:heating)
    end
  end

  state :heating do
    always do
      target(:boiling)
      guard(%{context: c}, do: c.temp > 100)
    end
  end

  state :boiling do
    always do
      target(:heating)
      guard(%{context: c}, do: c.temp <= 100)
    end
  end

  on :update_temp do
    action(assigns(%{temp: & &1.event.temp}))
  end

  setup do
    pid = start_supervised!({__MODULE__, []})

    [pid: pid]
  end

  test "update temp" do
    machine = Machine.init(__MODULE__)
    machine = Machine.transition(machine, %{type: :boil})

    assert machine.state == :heating

    machine = Machine.transition(machine, %{type: :update_temp, temp: 101})

    assert machine.state == :boiling

    machine = Machine.transition(machine, %{type: :update_temp, temp: 50})

    assert machine.state == :heating
  end
end
