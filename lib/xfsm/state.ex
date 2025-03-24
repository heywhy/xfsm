defmodule XFsm.State do
  @moduledoc """
  Documentation for `XFsm.State`.
  """

  alias XFsm.Always
  alias XFsm.Event

  @enforce_keys [:name]
  defstruct [:name, :exit, :entry, always: [], events: []]

  @type t :: %__MODULE__{
          name: atom(),
          exit: nil | XFsm.callback(),
          entry: nil | XFsm.callback(),
          always: [Always.t()],
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

  @spec add_always(t(), Always.t()) :: t()
  def add_always(%__MODULE__{always: always} = state, %Always{} = a) do
    struct!(state, always: [a] ++ always)
  end
end
