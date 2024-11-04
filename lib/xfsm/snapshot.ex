defmodule XFsm.Snapshot do
  @moduledoc """
  Documentation for `XFsm.Snapshot`.
  """

  @enforce_keys [:state, :context]
  defstruct [:state, :context]

  @type t :: %__MODULE__{
          state: atom(),
          context: nil | map()
        }
end
