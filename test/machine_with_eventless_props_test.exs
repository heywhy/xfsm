defmodule XFsm.MachineWithEventlessPropsTest do
  alias XFsm.Machine
  use ExUnit.Case
  use XFsm.Machine

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
    # entry(:turn_off_light)

    always do
      target(:heating)
      guard(%{context: c}, do: c.temp <= 100)
    end
  end

  on :update_temp do
    action(assigns(%{temp: & &1.event.temp}))
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
