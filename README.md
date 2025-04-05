# XFsm

XFsm is a declarative finite state machine library for [Elixir](https://elixir-lang.org/).

It uses [event-driven](./docs/transitions.md) programming, [state machines](./docs/state-machines.md) and actors to handle complex logic in predictable and robust ways.

It provides very easy to use APIs which makes looking at a declaration very easy to understand.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `xfsm` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:xfsm, "~> 0.3.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/xfsm>.

