defmodule XFsm.MachineWithActionsTest do
  use ExUnit.Case, async: true
  use XFsm.Machine

  alias XFsm.Machine

  import ExUnit.CaptureIO

  initial(:active)

  state :active do
    entry(:activate)
    exit(:deactivate)

    on :toggle do
      target(:inactive)
      action(:notify)
    end
  end

  state :inactive do
    on :toggle do
      target(:active)
      action(%{method: :notify, params: %{message: "Some notification"}})
    end
  end

  on :* do
    action(%{event: e}, do: IO.puts("Unhandled event: #{inspect(e)}"))
  end

  defa activate() do
    IO.puts("Activating")
  end

  defa deactivate() do
    IO.puts("Deactivating")
  end

  defa notify(_, %{message: message}) do
    IO.puts(message)
  end

  defa notify(_, _) do
    IO.puts("Default message")
  end

  test "outputs in the order of method execution" do
    {machine, output} =
      with_io(fn ->
        __MODULE__
        |> Machine.init()
        |> Machine.transition(%{type: :toggle})
        |> Machine.transition(%{type: :toggle})
      end)

    expected_output = [
      "Activating",
      "Deactivating",
      "Default message",
      "Some notification",
      "Activating"
    ]

    assert %{state: :active} = machine
    assert String.trim(output) == Enum.join(expected_output, "\n")
  end

  test "the catch all event handler is invoked" do
    {machine, output} =
      with_io(fn ->
        __MODULE__
        |> Machine.init()
        |> Machine.transition(%{type: :unknown})
      end)

    expected_output = [
      "Activating",
      "Unhandled event: %{type: :unknown}"
    ]

    assert %{state: :active} = machine
    assert String.trim(output) == Enum.join(expected_output, "\n")
  end
end
