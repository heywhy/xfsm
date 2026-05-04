# Machines

A [state machine](./state-machines.md) is model that describes the behavior of something, for example [lightbulb](./state-machines.md#states-in-xfsm). Finite state machines describe how state of an object transitions to another state when an [events](./transitions.md) occurs.

> #### Info {: .info}
>
> State machines help build reliable and robust software. [Read more about the benefits of state machines](./state-machines.md).

## Creating a state machine

In [XFsm](../README.md), a state machine is created using the `XFsm.Machine` module:

```elixir
defmodule Feedback do
  use XFsm.Actor
  use XFsm.Machine

  initial :question

  state :question do
    on :"feedback.good", do: target :thanks
  end

  state :thanks do
    # ...
  end

  # ...
end
```

In this example, the machine has two states: `question` and `thanks`. The `question` state has a transition to the `thanks` state when the `feedback.good` event is sent to the machine.

```elixir
{:ok, pid} = Feedback.start_link()

XFsm.Actor.subscribe(pid, &IO.inspect(&1.state))
# logs 'question'

XFsm.Actor.send(pid, %{type: :"feedback.good"})
# logs 'thanks'
```

## Creating GenServers from machines

A machine contains the logic of a [GenServer](`m:GenServer`). Multiple GenServers can be created from the same machine declaration, and each of those processes will exhibit the same behavior, reaction to received events.

To create a GenServer make sure your machine has the line `use XFsm.Actor` or call `XFsm.Actor.start_link/1`.

```elixir
{:ok, pid} = Feedback.start_link()

# OR

{:ok, pid} = XFsm.Actor.start_link(module: Feedback)

XFsm.Actor.subscribe(pid, &IO.inspect(&1.state))
# logs 'question'
```

## Providing implementations

Machine implementations are language-specific code that is executed but not directly related to the state machine's logic (states and transitions). This includes:

* [Actions](./actions.md), which are fire-and-forget side-effects.
* [Guards](./guards.md), which are conditions that determines whether a transition should be taken.

You can override the default implementations by **providing** implementations via options to the machine.

```elixir
defmodule Feedback do
  use XFsm.Actor
  use XFsm.Machine

  initial :rate

  state :rate do
    entry :do_something
  end

  def do_something(_), do: IO.puts("hello")
end

{:ok, pid} = Feedback.start_link(actions: %{do_something: fn _ -> IO.puts("world") end})
# logs 'world'
```
