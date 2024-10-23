defmodule XFsm.Machine do
  @moduledoc false

  alias XFsm.State

  defstruct [:initial, context: %{}, states: []]

  @type t :: %__MODULE__{
          initial: nil | atom(),
          context: map() | (-> map()) | (map() -> map()),
          states: [State.t()]
        }
end
