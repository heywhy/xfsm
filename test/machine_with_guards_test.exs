defmodule XFsm.MachineWithGuardsTest do
  use ExUnit.Case, async: true
  use XFsm.Machine

  alias XFsm.Machine

  import ExUnit.CaptureIO

  initial(:active)

  context(%{can_activate?: false})

  state :inactive do
    on :toggle do
      target(:active)
      guard(:can_be_toggled?)
    end

    on :toggle do
      action(:notify_not_allowed)
    end
  end

  state :active do
    on :toggle do
      target(:inactive)
      guard(%{method: :is_after_time?, params: %{time: "16:00"}})
    end
  end

  defg(can_be_toggled?(%{context: context}), do: context.can_activate?)

  defg(is_after_time?(_, %{time: time}), do: time == "16:00")

  defa(notify_not_allowed(), do: IO.puts("Cannot be toggled"))

  test "outputs cannot be toggled" do
    {machine, output} =
      with_io(fn ->
        __MODULE__
        |> Machine.init()
        |> Machine.transition(%{type: :toggle})
        |> Machine.transition(%{type: :toggle})
      end)

    assert %{state: :inactive} = machine
    assert String.trim(output) == "Cannot be toggled"
  end
end
