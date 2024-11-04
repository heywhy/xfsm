defmodule XFsm.State do
  @moduledoc """
  Documentation for `XFsm.State`.
  """

  alias XFsm.Event

  defstruct [:name, :exit, :entry, events: []]

  @type t :: %__MODULE__{
          name: atom(),
          exit: nil | XFsm.callback(),
          entry: nil | XFsm.callback(),
          events: [Event.t()]
        }

  @spec add_event(t(), Event.t()) :: t()
  def add_event(%__MODULE__{events: events} = state, %Event{} = event) do
    struct!(state, events: [event] ++ events)
  end

  @spec add_event(t(), atom(), keyword()) :: t()
  def add_event(%__MODULE__{events: events} = state, name, opts \\ []) do
    opts = Keyword.validate!(opts, ~w[target action guard]a)
    event = struct!(Event, [name: name] ++ opts)

    struct!(state, events: [event] ++ events)
  end
end
