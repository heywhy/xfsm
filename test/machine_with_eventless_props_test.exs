defmodule XFsm.MachineWithEventlessPropsTest do
  use ExUnit.Case, async: true
  use XFsm.Actor
  use XFsm.Machine

  alias XFsm.Actor
  alias XFsm.Snapshot

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
      guard(:check?, %{sign: :gt, value: 100})
    end
  end

  state :boiling do
    always do
      target(:heating)
      guard(:check?, %{sign: :lte, value: 100})
    end
  end

  root do
    on :update_temp do
      action(:assign, &update_temp/1)
    end
  end

  def check?(arg, %{sign: :gt, value: _} = params) do
    %{context: %{temp: temp}} = arg
    %{value: value} = params

    temp > value
  end

  def check?(arg, %{sign: :lte, value: _} = params) do
    %{context: %{temp: temp}} = arg
    %{value: value} = params

    temp <= value
  end

  def update_temp(%{event: e}), do: %{temp: e.temp}

  setup do
    pid = start_supervised!({__MODULE__, []})

    [pid: pid]
  end

  test "update temp", %{pid: pid} do
    :ok = Actor.send(pid, %{type: :boil})

    assert %Snapshot{state: :heating} = Actor.snapshot(pid)

    :ok = Actor.send(pid, %{type: :update_temp, temp: 101})

    assert %Snapshot{state: :boiling} = Actor.snapshot(pid)

    :ok = Actor.send(pid, %{type: :update_temp, temp: 50})

    assert %Snapshot{state: :heating} = Actor.snapshot(pid)
  end
end
