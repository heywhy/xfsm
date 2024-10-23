defmodule XFsm.Event do
  @moduledoc false

  @enforce_keys [:name]
  defstruct [:name, :target, :action, :guard]

  @type t :: %__MODULE__{
          name: atom(),
          target: nil | atom(),
          action: nil | fun(),
          guard: nil | fun()
        }
end
