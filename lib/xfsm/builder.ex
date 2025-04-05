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

  defmacro state(name, do: block) when is_atom(name) do
    opts = %{
      methods: [],
      state: name,
      module: __CALLER__.module
    }

    statements =
      case block do
        {:__block__, _, lines} -> lines
        expr -> [expr]
      end

    {exprs, opts} =
      Enum.reduce(
        statements,
        {[], opts},
        fn
          {attr, _, [action]}, {exprs, opts} when attr in [:entry, :exit] and is_atom(action) ->
            expr = add_attr({:state, [], __MODULE__}, attr, action)

            e =
              quote do
                state = unquote(expr)
              end

            {[e] ++ exprs, opts}

          {attr, _, _} = expr, {exprs, opts} when attr in [:entry, :exit] ->
            {expr, opts} = add_attr(expr, {:state, [], __MODULE__}, attr, opts)

            e =
              quote do
                state = unquote(expr)
              end

            {[e] ++ exprs, opts}

          {:on, _, _} = expr, {exprs, opts} ->
            {expr, opts} = add_event(expr, {:state, [], __MODULE__}, opts)

            e =
              quote do
                state = unquote(expr)
              end

            {[e] ++ exprs, opts}

          {:always, _, _} = expr, {exprs, opts} ->
            {expr, opts} = add_always(expr, {:state, [], __MODULE__}, opts)

            e =
              quote do
                state = unquote(expr)
              end

            {[e] ++ exprs, opts}
        end
      )

    methods = Macro.escape(opts.methods)

    quote do
      state = %State{name: unquote(name)}

      unquote_splicing(exprs)

      @states state
      @methods unquote(methods)
    end
  end

  defmacro on(name, do: block) when is_atom(name) do
    opts = %{
      methods: [],
      state: :__machine__,
      module: __CALLER__.module
    }

    {expr, opts} =
      add_event(
        {:on, [], [name, [do: block]]},
        {:state, [], __MODULE__},
        opts
      )

    expr =
      quote do
        state = unquote(expr)
      end

    methods = Macro.escape(opts.methods)

    quote do
      state = %State{name: :__global__}

      unquote(expr)

      @states state
      @methods unquote(methods)
    end
  end

  defmacro defa({method, _, arguments}, do: block) do
    %{module: module} = __CALLER__

    gen_method(module, :action, method, arguments, do: block)
  end

  defmacro defg({method, _, arguments}, do: block) do
    %{module: module} = __CALLER__

    gen_method(module, :guard, method, arguments, do: block)
  end

  defp gen_method(module, sect, name, arguments, do: block) when is_atom(name) do
    method_def = {module, sect, name, {}, {}}
    method = method_def_to_name(method_def)

    fun =
      {:&, [],
       [
         {:/, [],
          [
            {{:., [], [module, method]}, [no_parens: true], []},
            Enum.count(arguments)
          ]}
       ]}

    quote do
      Module.put_attribute(
        __MODULE__,
        :"#{unquote(sect)}s",
        {unquote(name), unquote(fun)}
      )

      def unquote(method)(unquote_splicing(arguments)) do
        unquote(block)
      end
    end
  end

  defp add_attr(acc, attr, value) do
    quote do
      struct!(unquote(acc), [{unquote(attr), unquote(value)}])
    end
  end

  defp add_attr({attr, _, [argument, [do: block]]}, acc, attr, opts) when is_atom(attr) do
    %{state: state, methods: methods, module: module} = opts
    callback = :"#{state}_#{attr}"
    {method_def, fun} = ast_to_callback(argument, block, module, callback, methods)

    exprs =
      quote do
        state = unquote(acc)

        Map.update!(state, unquote(attr), fn
          nil -> [unquote(fun)]
          entries when is_list(entries) -> [unquote(fun)] ++ entries
        end)
      end

    {exprs, %{opts | methods: [method_def] ++ methods}}
  end

  defp add_attr({attr, c, [{m, o, args}]}, acc, attr, opts) when is_atom(attr) do
    argument = {:arg, [], nil}
    expr = {m, o, [argument | args]}

    add_attr({attr, c, [argument, [do: expr]]}, acc, attr, opts)
  end

  defp add_always({:always, _, [[do: block]]}, acc, opts) do
    exprs =
      case block do
        {:__block__, _, exprs} -> exprs
        expr -> [expr]
      end

    {ast, opts} =
      Enum.reduce(
        exprs,
        {Macro.escape(%Always{}), opts},
        fn
          {field, _, [value]}, {exprs, opts} when is_atom(value) ->
            {add_attr(exprs, field, value), opts}

          {attr, _, _} = expr, acc when attr in [:action, :guard] ->
            add_event_handler(:always, expr, acc)
        end
      )

    exprs =
      quote do
        unquote(acc) |> State.add_always(unquote(ast))
      end

    {exprs, opts}
  end

  defp add_event({:on, _, [event, [do: block]]}, acc, opts) when is_atom(event) do
    exprs =
      case block do
        {:__block__, _, exprs} -> exprs
        expr -> [expr]
      end

    {ast, opts} =
      Enum.reduce(
        exprs,
        {Macro.escape(%Event{name: event}), opts},
        fn
          {field, _, [value]}, {exprs, opts} when is_atom(value) ->
            {add_attr(exprs, field, value), opts}

          {field, _, [{:%{}, _, _} = expr]}, {exprs, opts} ->
            {add_attr(exprs, field, expr), opts}

          {attr, _, _} = expr, acc when attr in [:action, :guard] ->
            add_event_handler(event, expr, acc)
        end
      )

    exprs =
      quote do
        unquote(acc) |> State.add_event(unquote(ast))
      end

    {exprs, opts}
  end

  defp add_event({:on, _, [event, attrs]}, acc, opts) when is_atom(event) do
    expr =
      quote do
        unquote(acc) |> State.add_event(unquote(event), unquote(attrs))
      end

    {expr, opts}
  end

  defp add_event_handler(event, {attr, _, [argument, expr]}, {exprs, opts}) do
    %{state: state, methods: methods, module: module} = opts
    callback = :"#{state}_#{event}_#{attr}"

    block =
      case expr do
        [do: block] -> block
        expr -> expr
      end

    {method_def, fun} = ast_to_callback(argument, block, module, callback, methods)

    exprs =
      quote do
        unquote(exprs) |> struct!([{unquote(attr), unquote(fun)}])
      end

    {exprs, %{opts | methods: [method_def] ++ methods}}
  end

  defp add_event_handler(event, {attr, o, [{m, o1, args}]}, acc) do
    argument = {:arg, [], nil}
    expr = {m, o1, [argument | args]}

    add_event_handler(event, {attr, o, [argument, expr]}, acc)
  end

  defp add_event_handler(event, {attr, o, [expr]}, acc) do
    add_event_handler(event, {attr, o, [{:_, [], nil}, expr]}, acc)
  end

  defp ast_to_callback(argument, block, module, callback, methods) do
    existing = Enum.count(methods, &match?({^module, ^callback, _, _, _}, &1))
    method_def = {module, callback, existing + 1, argument, block}
    method = method_def_to_name(method_def)
    aliases = Module.split(module) |> Enum.map(&String.to_atom/1)

    fun =
      {:&, [],
       [
         {:/, [],
          [
            {{:., [], [{:__aliases__, [], aliases}, method]}, [no_parens: true], []},
            1
          ]}
       ]}

    {method_def, fun}
  end

  @doc false
  @spec method_def_to_name({module(), atom(), integer() | atom(), tuple(), tuple()}) :: atom()
  def method_def_to_name({_module, callback, tag, _argument, _block}), do: :"#{callback}_#{tag}"

  defmacro __using__(_env) do
    quote do
      import XFsm.Builder

      @before_compile XFsm.Builder

      Module.register_attribute(__MODULE__, :guards, accumulate: true)
      Module.register_attribute(__MODULE__, :actions, accumulate: true)
      Module.register_attribute(__MODULE__, :methods, accumulate: true)
      Module.register_attribute(__MODULE__, :initial_state, accumulate: false)
      Module.register_attribute(__MODULE__, :states, accumulate: true)
    end
  end

  defmacro __before_compile__(_env) do
    quote bind_quoted: [] do
      methods = Module.get_attribute(__MODULE__, :methods, []) |> Enum.flat_map(& &1)

      for {_, _method, _tag, argument, body} = definition <- methods do
        name = XFsm.Builder.method_def_to_name(definition)

        def unquote(name)(unquote(argument)) do
          unquote(body)
        end
      end

      unless Module.defines?(__MODULE__, {:__context__, 1}) do
        @doc false
        def __context__(_), do: nil
      end

      @doc false
      def __attr__(:guards), do: Enum.into(@guards, %{})
      def __attr__(:actions), do: Enum.into(@actions, %{})
      def __attr__(:initial_state), do: @initial_state
      def __attr__(:states), do: Enum.reverse(@states)
    end
  end
end
