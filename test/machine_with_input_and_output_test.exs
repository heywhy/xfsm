defmodule XFsm.MachineWithInputAndOutputTest do
  use ExUnit.Case, async: true
  use XFsm.Machine

  alias XFsm.Machine

  import ExUnit.CaptureIO

  initial(:active)

  context(%{input: input}, do: %{message: "Hello, #{input.name}"})

  state :active do
    entry(%{context: context}, do: IO.puts(context.message))
  end

  test "pass input as argument to context" do
    {machine, output} = with_io(fn -> Machine.init(__MODULE__, input: %{name: "David"}) end)

    assert %{state: :active} = machine
    assert String.trim(output) == "Hello, David"
  end
end
