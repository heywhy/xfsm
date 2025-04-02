defmodule XFsm.Event do
  @moduledoc """
  Documentation for `XFsm.Event`.
  """

  @enforce_keys [:name]
  defstruct [:name, :target, :action, :guard]

  @type t :: %__MODULE__{
          name: atom(),
          target: nil | atom(),
          action: nil | XFsm.callback(),
          guard: nil | XFsm.callback()
        }
end
