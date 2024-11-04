defmodule XFsm.PaymentActorTest do
  use ExUnit.Case
  use XFsm.Actor
  use XFsm.Machine

  alias XFsm.Actor
  alias XFsm.Snapshot

  initial(:pending)

  context(%{input: input}, do: %{payment: input.payment})

  state :pending do
    on :capture do
      target(:poll_incoming)

      guard %{context: %{payment: payment}} do
        payment.status == :pending and payment.direction == :incoming
      end

      action %{context: context} do
        %{payment: %{customer: customer} = payment} = context

        payment_method = new_payment_method(customer.first_name, customer.last_name)

        %{context | payment: Map.put(payment, :payment_method, payment_method)}
      end
    end

    on :capture do
      target(:poll_outgoing)

      guard %{context: %{payment: payment}, event: event} do
        payment.status == :pending and payment.direction == :outgoing and
          is_map(event[:payment_method]) and
          match?(%{type: :bank_account}, event[:payment_method])
      end

      action %{context: context, event: %{payment_method: payment_method}} do
        %{payment: payment} = context

        %{context | payment: Map.put(payment, :payment_method, payment_method)}
      end
    end
  end

  state :poll_incoming do
  end

  state :poll_outgoing do
  end

  setup context do
    customer = %{
      first_name: "Arnold",
      last_name: "Blocks"
    }

    payment = %{
      id: 1,
      customer: customer,
      status: context[:status] || :pending,
      direction: context[:direction] || :incoming
    }

    opts = [
      input: %{payment: payment}
    ]

    [payment: payment, pid: start_supervised!({__MODULE__, opts})]
  end

  test "actor is running", %{pid: pid} do
    assert Process.alive?(pid)
    assert %Snapshot{state: :pending} = Actor.snapshot(pid)
  end

  test "capture incoming payment", %{pid: pid} do
    assert %Snapshot{state: :pending, context: %{payment: payment}} = Actor.snapshot(pid)
    refute is_map(payment[:payment_method])

    assert :ok = Actor.send(pid, %{type: :capture})

    assert %Snapshot{state: :poll_incoming, context: %{payment: payment}} = Actor.snapshot(pid)
    assert is_map(payment[:payment_method])
  end

  @tag direction: :outgoing
  test "fail to capture outgoing payment when payment method is missing", %{pid: pid} do
    assert %Snapshot{state: :pending} = Actor.snapshot(pid)
    assert :ok = Actor.send(pid, %{type: :capture})
    assert %Snapshot{state: :pending, context: %{payment: payment}} = Actor.snapshot(pid)
    refute payment[:payment_method]
  end

  @tag direction: :outgoing
  test "capture outgoing payment", %{pid: pid} do
    payment_method = new_payment_method("Johnson", "Olawuyi")

    assert %Snapshot{state: :pending, context: %{payment: payment}} = Actor.snapshot(pid)
    refute is_map(payment[:payment_method])
    assert :ok = Actor.send(pid, %{type: :capture, payment_method: payment_method})
    assert %Snapshot{state: :poll_outgoing, context: %{payment: payment}} = Actor.snapshot(pid)
    assert is_map(payment[:payment_method])
  end

  defp new_payment_method(first_name, last_name) do
    %{
      type: :bank_account,
      bank_name: "First Bank",
      account_number: "00000000000",
      account_name: "#{first_name} #{last_name}"
    }
  end
end
