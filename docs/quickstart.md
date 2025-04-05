# Quickstart

This guide will help you get started with XFsm. You will learn how to create a state machine, create an actor from the state machine, send events to the actor, and use it outside of an actor.

> #### Info {: .info}
>
> The quickest way to start with XFsm is to check out the [Basic Payment Machine](https://github.com/heywhy/xfsm/blob/main/test/payment_actor_test.exs). There you will find an example of a machine that covers the basics of XFsm.

## Installing XFsm

[XFsm](../README.md) is a declarative state management and orchestration library for Elixir.

```elixir
def deps do
  [
    {:xfsm, "~> 0.3"}
  ]
end
```

## Create a Machine

In XFsm, a [machine](../lib/xfsm/machine.ex) is a module that contains all the logic for the actor. In this example, we will create a simple toggle machine that can be in one of two states: `on` or `off`. The `press` event will toggle the state between `on` and `off`.

```elixir
defmodule LightbulbSwitch do
  use XFsm.Actor
  use XFsm.Machine

  initial(:off)

  state :off do
    on :press do
      target(:on)
    end
  end

  state :on do
    on :press do
      target(:off)
    end
  end
end
```

Just by looking at the declaration, you can get a sense of how it works. To familiarize yourself with the foundational concepts, read our [introduction to state machines guide](./machines.md).

## Start an Actor and Send Events

An actor is a running process that can receive events, send events to other actors, and change its behavior based on the events it receives.

```elixir
alias XFsm.{Actor, Snapshot}

# Here, we start the actor.
{:ok, pid} = LightbulbSwitch.start_link()

# Grab a snapshot of the actor's state.
%Snapshot{state: :off} = Actor.snapshot(pid)

# Send the `press` event to the actor.
:ok = Actor.send(pid, %{type: :press})

# Notice that the state of the actor has now changed?!
%Snapshot{state: :on} = Actor.snapshot(pid)

# Send another `press` event to the actor.
:ok = Actor.send(pid, %{type: :press})

# Now we're back to the initial state.
%Snapshot{state: :off} = Actor.snapshot(pid)
```

> #### Info {: .info}
>
> Ensure your machine utilizes the `use XFsm.Actor` behavior. Additionally, XFsm actors are GenServers under the hood but have a more restricted scope of behavior.

## Context Data

Context is how you store data within a state machine actor.

```elixir
defmodule ToggleMachine do
  use XFsm.Actor
  use XFsm.Machine

  import XFsm.Actions

  initial(:inactive)
  context(%{count: 0})

  state :inactive do
    on :toggle do
      target(:active)
    end
  end

  state :active do
    # Increment `count` every time we transition into this state.
    entry(assigns(%{count: &(&1.context.count + 1)}))

    on :toggle do
      target(:inactive)
    end
  end
end
```

## Machine Input

[Machine Input](./input.md) is how initial data can be passed to a machine actor. Meanwhile, [Guards](./guards.md) are used to conditionally allow or disallow transitions.

```elixir
defmodule ToggleMachine do
  use XFsm.Actor
  use XFsm.Machine

  import XFsm.Actions

  initial(:inactive)
  context(%{input: input}, do: %{count: 0, max_count: input.max_count})

  state :inactive do
    on :toggle do
      target(:active)
      guard(%{context: context}, do: context.count < context.max_count)
    end
  end

  state :active do
    entry(assigns(%{count: &(&1.context.count + 1)}))

    on :toggle do
      target(:inactive)
    end
  end
end

alias XFsm.Actor

{:ok, pid} = ToggleMachine.start_link(input: %{max_count: 10})

Actor.subscribe(pid, &IO.inspect/1)

Actor.send(pid, %{type: :toggle})
```
