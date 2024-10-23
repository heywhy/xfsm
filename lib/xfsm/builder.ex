defmodule XFsm.Builder do
  @moduledoc false

  alias XFsm.Event
  alias XFsm.State

  defmacro initial(state) when is_atom(state) do
    quote do
      @initial_state unquote(state)
    end
  end

  defmacro context(argument, do: block) do
    quote do
      def __context__(unquote(argument)), do: unquote(block)
    end
  end

  defmacro context({:%{}, _, _} = ast) do
    quote do
      context _ do
        unquote(ast)
      end
    end
  end

  defmacro context(do: block) do
    quote do
      context _ do
        unquote(block)
      end
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
      end

    {exprs, opts} =
      Enum.reduce(
        statements,
        {[], opts},
        fn
          {attr, _, [action]}, {exprs, opts} when attr in [:entry, :exit] ->
            expr = add_attr({:state, [], __MODULE__}, attr, action)

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

          _, acc ->
            acc
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

  defp add_attr(acc, attr, value) when is_atom(value) do
    quote do
      unquote(acc) |> Map.put(unquote(attr), unquote(value))
    end
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

          {attr, _, [argument, [do: block]]}, {exprs, opts} when attr in [:action, :guard] ->
            %{state: state, methods: methods, module: module} = opts
            callback = :"#{state}_#{event}_#{attr}"
            {method_def, fun} = ast_to_callback(argument, block, module, callback, methods)

            exprs =
              quote do
                unquote(exprs) |> struct!([{unquote(attr), unquote(fun)}])
              end

            {exprs, %{opts | methods: [method_def] ++ methods}}

          {attr, _, [[do: block]]}, {exprs, opts} when attr in [:action, :guard] ->
            %{state: state, methods: methods, module: module} = opts
            callback = :"#{state}_#{event}_#{attr}"
            {method_def, fun} = ast_to_callback({:_, [], nil}, block, module, callback, methods)

            exprs =
              quote do
                unquote(exprs) |> struct!([{unquote(attr), unquote(fun)}])
              end

            {exprs, %{opts | methods: [method_def] ++ methods}}

          _, acc ->
            acc
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

  @spec method_def_to_name({module(), atom(), integer(), tuple(), tuple()}) :: atom()
  def method_def_to_name({_module, callback, tag, _argument, _block}), do: :"#{callback}_#{tag}"

  defmacro __using__(_env) do
    quote do
      import XFsm.Builder

      @before_compile XFsm.Builder

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

      def __attr__(:actions), do: @actions
      def __attr__(:initial_state), do: @initial_state
      def __attr__(:states), do: Enum.reverse(@states)
      def __attr__(:methods), do: Enum.flat_map(@methods, & &1)
    end
  end
end
