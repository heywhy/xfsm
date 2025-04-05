defmodule XFsm.Always do
  @moduledoc """
  Documentation for `XFsm.Always`.
  """

  defstruct [:target, :action, :guard]

  @type t :: %__MODULE__{
          target: nil | XFsm.callback(),
          action: nil | XFsm.callback(),
          guard: nil | XFsm.callback()
        }
end
