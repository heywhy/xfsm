defmodule XfsmTest do
  use ExUnit.Case, async: true

  alias XFsm.Snapshot

  test "stringify snapshot" do
    string = "'active' with context %{count: 1}"
    snapshot = %Snapshot{state: :active, context: %{count: 1}}

    assert to_string(snapshot) == string
  end
end
