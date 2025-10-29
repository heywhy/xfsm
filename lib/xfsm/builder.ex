defmodule XFsm.Builder do
  @moduledoc """
  Documentation for `XFsm.Builder`.
  """

  alias XFsm.Always
  alias XFsm.Event
  alias XFsm.State

  defmacro initial(state) when is_atom(state) do
    quote do
      @initial_state unquote(state)
    end
  end

  defmacro context(argument, do: block) do
    quote do
      @doc false
      def __context__(unquote(argument)), do: unquote(block)
    end
  end

  defmacro context({:%{}, _, _} = ast) do
    quote do
      context(_, do: unquote(ast))
    end
  end

  defmacro context(do: block) do
    quote do
      context(_, do: unquote(block))
    end
  end

  # TODO: dispatch a function to the large bulk of codegen
  # see https://hexdocs.pm/elixir/macro-anti-patterns.html#large-code-generation
  defmacro state(name, do: block) when is_atom(name) do
    opts = %{
      state: name,
      env: __CALLER__,
      module: __CALLER__.module
    }

    statements =
      case block do
        {:__block__, _, lines} -> lines
        expr -> [expr]
      end

    exprs =
      Enum.reduce(
        statements,
        [],
        fn
          {attr, _, _} = expr, exprs when attr in ~w[entry exit]a ->
            expr = do_add_state_attr(expr, {:state, [], __MODULE__}, opts)

            e =
              quote do
                state = unquote(expr)
              end

            [e] ++ exprs

          {:on, _, _} = expr, exprs ->
            expr = add_event(expr, {:state, [], __MODULE__}, opts)

            e =
              quote do
                state = unquote(expr)
              end

            [e] ++ exprs

          {:always, _, _} = expr, exprs ->
            expr = add_always(expr, {:state, [], __MODULE__}, opts)

            e =
              quote do
                state = unquote(expr)
              end

            [e] ++ exprs
        end
      )

    quote do
      state = %State{name: unquote(name)}

      unquote_splicing(exprs)

      @states state
    end
  end

  defmacro root(do: block) do
    quote do
      state(:__global__, do: unquote(block))
    end
  end

  defp do_add_state_attr(expr, var, opts) do
    do_add_event_attr(expr, opts, var)
  end

  defp do_add_event_attr({:target, _, [state]}, _opts, acc) when is_atom(state) do
    quote do
      struct!(unquote(acc), target: unquote(state))
    end
  end

  @attrs ~w[action entry exit]a
  @actions ~w[assign cancel send_event]a

  defp do_add_event_attr({attr, _, [action, _] = expr}, opts, acc)
       when attr in @attrs and action in @actions do
    %{env: env} = opts
    [_, arg] = expr

    ast =
      case arg do
        {:&, _, [{:/, _, [{method, _, nil}, 1]}]} -> capture_from(env, method, 1)
        {:%{}, _, _} = arg -> arg
        arg when is_atom(arg) -> arg
        arg when is_list(arg) -> arg
      end

    quote do
      struct!(unquote(acc), [{unquote(attr), {:"xfsm.#{unquote(action)}", unquote(ast)}}])
    end
  end

  defp do_add_event_attr({attr, _, expr}, opts, acc) when attr in ~w[action entry exit guard]a do
    fun = fun_from_expr(expr, opts)

    quote do
      struct!(unquote(acc), [{unquote(attr), unquote(fun)}])
    end
  end

  defp fun_from_expr(expr, opts) do
    %{env: env} = opts

    case expr do
      [method] when is_atom(method) -> capture_from(env, method, 1)
      [method, param] when is_atom(method) -> {capture_from(env, method, 2), param}
    end
  end

  defp capture_from(env, fun, arity) do
    env
    |> find_fun_owner(fun, arity)
    |> method_capture_to_ast(fun, arity)
  end

  defp find_fun_owner(env, fun, arity) do
    case Macro.Env.lookup_import(env, {fun, arity}) do
      [] -> env.module
      [{ctx, module}] when ctx in ~w[function macro]a -> module
    end
  end

  defp add_always({:always, _, [[do: block]]}, acc, opts) do
    exprs =
      case block do
        {:__block__, _, exprs} -> exprs
        expr -> [expr]
      end

    ast =
      Enum.reduce(
        exprs,
        Macro.escape(%Always{}),
        &do_add_event_attr(&1, opts, &2)
      )

    quote do
      unquote(acc) |> State.add_always(unquote(ast))
    end
  end

  defp add_event({:on, _, [event, [do: block]]}, acc, opts) when is_atom(event) do
    exprs =
      case block do
        {:__block__, _, exprs} -> exprs
        expr -> [expr]
      end

    ast =
      Enum.reduce(
        exprs,
        Macro.escape(%Event{name: event}),
        &do_add_event_attr(&1, opts, &2)
      )

    quote do
      unquote(acc) |> State.add_event(unquote(ast))
    end
  end

  defp method_capture_to_ast(module, method, arity) do
    aliases = Module.split(module) |> Enum.map(&String.to_atom/1)

    {:&, [],
     [
       {:/, [],
        [
          {{:., [], [{:__aliases__, [], aliases}, method]}, [no_parens: true], []},
          arity
        ]}
     ]}
  end

  defmacro __using__(_env) do
    quote do
      import XFsm.Builder

      @before_compile XFsm.Builder

      Module.register_attribute(__MODULE__, :initial_state, accumulate: false)
      Module.register_attribute(__MODULE__, :states, accumulate: true)
    end
  end

  defmacro __before_compile__(_env) do
    quote bind_quoted: [] do
      unless Module.defines?(__MODULE__, {:__context__, 1}) do
        @doc false
        def __context__(_), do: nil
      end

      @doc false
      def __attr__(:initial_state), do: @initial_state
      def __attr__(:states), do: Enum.reverse(@states)
    end
  end
end
