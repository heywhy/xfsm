defmodule XFsm.ActionsTest do
  use ExUnit.Case, async: true

  import XFsm.Actions

  test "send event to actor" do
    event = %{type: :testing}
    arg = %{actor: self(), context: %{}}

    assert %{} = send_event(arg, event)
    assert_received {:"$gen_cast", {:send, ^event}}
  end

  test "send event to actor after delay" do
    event = %{type: :testing}
    arg = %{actor: self(), context: %{}}

    assert %{} = send_event(arg, event, delay: 10)
    assert_receive {:"$gen_cast", {:send, ^event}}, 12
  end

  test "passing function to send_event gets invoked" do
    context = %{id: 1}
    arg = %{actor: self(), context: context}

    assert ^context = send_event(arg, &%{type: :delete, user_id: &1.context.id})
    assert_received {:"$gen_cast", {:send, %{type: :delete, user_id: 1}}}
  end

  test "delayed sent event can be cancelled" do
    arg = %{actor: self(), context: %{}}
    context = send_event(arg, %{type: :test}, delay: 10, id: :some_id)

    assert %{} = cancel(%{arg | context: context}, :some_id)
    refute_receive {:"$gen_cast", {:send, %{type: :test}}}, 11
  end

  test "assigns updates the context" do
    arg = %{
      context: %{value: 1},
      event: %{type: :inc, value: 1}
    }

    assert %{value: 2, old_value: 1, name: "Fred"} =
             assigns(arg, %{
               name: "Fred",
               value: &(&1.event.value + 1),
               old_value: & &1.context.value
             })
  end
end
