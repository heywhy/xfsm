defmodule XFsm.PaymentActorTest do
  use ExUnit.Case, async: true
  use XFsm.Actor
  use XFsm.Machine

  alias XFsm.Actor
  alias XFsm.Snapshot

  initial(:pending)

  context(%{input: input}, do: %{payment: input.payment})

  state :pending do
    on :capture do
      target(:poll_incoming)
      guard(:capture?, %{direction: :incoming})
      action(:assign, &gen_payment_method/1)
    end

    on :capture do
      target(:poll_outgoing)
      guard(:capture?, %{direction: :outgoing})
      action(:assign, &send_payment/1)
    end
  end

  state :poll_incoming do
    entry(:send_event, event: %{type: :timeout}, id: :timeout, delay: 6)
    exit(:cancel, :timeout)

    on :timeout do
      target(:timeout)
    end
  end

  state :poll_outgoing do
  end

  state :timeout do
  end

  def capture?(
        %{context: %{payment: %{direction: :incoming = d}} = context},
        %{direction: d}
      ) do
    %{payment: payment} = context

    payment.status == :pending
  end

  def capture?(
        %{context: %{payment: %{direction: :outgoing = d}}} = arg,
        %{direction: d}
      ) do
    %{event: event, context: context} = arg
    %{payment: payment} = context

    payment.status == :pending and match?(%{type: :bank_account}, event[:payment_method])
  end

  def capture?(_, _), do: false

  def gen_payment_method(arg) do
    %{context: %{payment: payment} = context} = arg
    %{customer: customer} = payment

    payment_method = new_payment_method(customer.first_name, customer.last_name)
    updated_payment = Map.put(payment, :payment_method, payment_method)

    %{context | payment: updated_payment}
  end

  def send_payment(arg) do
    %{context: %{payment: payment} = context, event: %{payment_method: payment_method}} = arg

    updated_payment = Map.put(payment, :payment_method, payment_method)

    %{context | payment: updated_payment}
  end

  setup context do
    customer = %{
      first_name: "Arnold",
      last_name: "Blocks"
    }

    payment = %{
      id: 1,
      customer: customer,
      direction: context[:direction],
      status: context[:status] || :pending
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

  @tag direction: :incoming
  test "capture incoming payment", %{pid: pid} do
    assert %Snapshot{state: :pending, context: %{payment: payment}} = Actor.snapshot(pid)
    refute is_map(payment[:payment_method])

    assert :ok = Actor.send(pid, %{type: :capture})

    assert %Snapshot{state: :poll_incoming, context: %{payment: payment}} = Actor.snapshot(pid)
    assert is_map(payment[:payment_method])
  end

  @tag direction: :incoming
  test "captured incoming payment times out", %{pid: pid} do
    :ok = Actor.send(pid, %{type: :capture})

    Process.sleep(7)

    assert %Snapshot{state: :timeout} = Actor.snapshot(pid)
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
