defmodule MachineTest do
  use ExUnit.Case, async: true

  alias XFsm.Machine

  defmodule MissingInitialState do
    use XFsm.Machine

    state :one do
    end

    state :two do
    end
  end

  test "raise an error for missing initial state" do
    assert_raise ArgumentError,
                 """
                 An initial state has to be specified for the machine: MachineTest.MissingInitialState.
                 """,
                 fn ->
                   Machine.init(MissingInitialState)
                 end
  end
end
