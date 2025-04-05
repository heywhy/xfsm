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

  defimpl String.Chars do
    alias XFsm.Snapshot

    def to_string(%Snapshot{state: state, context: context}) do
      "'#{state}' with context #{inspect(context)}"
    end
  end
end
