defmodule XFsm.TicTacToeTest do
  use ExUnit.Case, async: true
  use XFsm.Actor
  use XFsm.Machine

  alias XFsm.Machine

  import XFsm.Actions

  defmodule Board do
    defstruct squares: {nil, nil, nil, nil, nil, nil, nil, nil, nil}

    @tags [:x, :o]

    def square(%__MODULE__{} = board, index)
        when is_integer(index) and index >= 1 and index <= 9 do
      elem(board.squares, index - 1)
    end

    def empty?(%__MODULE__{} = board, index), do: square(board, index) == nil

    def has_empty_square?(%__MODULE__{} = board) do
      Enum.any?(0..8, &(elem(board.squares, &1) == nil))
    end

    def draw?(%__MODULE__{} = board) do
      not has_empty_square?(board) and
        not (won?(board, :x) or won?(board, :o))
    end

    def won?(%__MODULE__{} = board, tag) when tag in @tags do
      %{squares: squares} = board

      siblings?(:x, squares, tag) or
        siblings?(:y, squares, tag) or
        siblings?(:z, squares, tag)
    end

    def put(%__MODULE__{} = board, index, tag)
        when is_integer(index) and index >= 1 and index <= 9 and tag in @tags do
      case empty?(board, index) do
        false ->
          board

        true ->
          squares = put_elem(board.squares, index - 1, tag)

          %__MODULE__{board | squares: squares}
      end
    end

    def to_iodata(%__MODULE__{} = board) do
      Enum.reduce(0..2, [], fn i, acc ->
        row = Enum.map_join(0..2, "|", &(elem(board.squares, i * 3 + &1) || "-"))

        Enum.concat(acc, ["|", row, "|\n"])
      end)
    end

    defp siblings?(:x, squares, tag) do
      Enum.reduce_while(0..2, false, fn i, acc ->
        fun? = &(elem(squares, i * 3 + &1) == tag)

        case Enum.all?(0..2, fun?) do
          true -> {:halt, true}
          false -> {:cont, acc}
        end
      end)
    end

    defp siblings?(:y, squares, tag) do
      Enum.reduce_while(0..2, false, fn i, acc ->
        fun? = &(elem(squares, i + &1 * 3) == tag)

        case Enum.all?(0..2, fun?) do
          true -> {:halt, true}
          false -> {:cont, acc}
        end
      end)
    end

    defp siblings?(:z, squares, tag) do
      fun? = &(elem(squares, &1) == tag)

      Enum.all?(0..8//4, fun?) or Enum.all?(2..6//2, fun?)
    end
  end

  initial(:x)
  context(%{input: i}, do: context_from_input(i))

  state :x do
    on :move do
      target(:o)
      guard(%{method: :can_move?, params: %{player: :x}})
      action(:make_move)
    end
  end

  state :o do
    on :move do
      target(:x)
      guard(%{method: :can_move?, params: %{player: :o}})
      action(:make_move)
    end
  end

  state :end do
  end

  root do
    always do
      target(:end)
      guard(%{method: :won?, params: %{player: :o}})
      action(assigns(%{winner: :o}))
    end

    always do
      target(:end)
      guard(%{method: :won?, params: %{player: :x}})
      action(assigns(%{winner: :x}))
    end

    always do
      target(:end)
      guard(%{method: :drawn?, params: %{player: :x}})
    end
  end

  defg can_move?(
         %{context: %{x: x}, event: %{ref: x, square: _}} = arg,
         %{player: :x}
       ) do
    %{context: %{board: board}, event: %{square: square}} = arg

    Board.empty?(board, square)
  end

  defg can_move?(
         %{context: %{o: o}, event: %{ref: o, square: _}} = arg,
         %{player: :o}
       ) do
    %{context: %{board: board}, event: %{square: square}} = arg

    Board.empty?(board, square)
  end

  defg won?(
         %{self: %{state: _}, context: %{board: _}} = arg,
         %{player: _} = params
       ) do
    %{self: %{state: state}, context: %{board: board}} = arg
    %{player: player} = params

    state != :end and Board.won?(board, player)
  end

  defg drawn?(%{self: %{state: _}, context: %{board: _}} = arg) do
    %{self: %{state: state}, context: %{board: board}} = arg

    state != :end and Board.draw?(board)
  end

  defa make_move(%{context: %{x: x} = c, event: %{ref: x, square: index}}) do
    %{board: board} = c
    board = Board.put(board, index, :x)

    %{c | board: board}
  end

  defa make_move(%{context: %{o: o} = c, event: %{ref: o, square: index}}) do
    %{board: board} = c
    board = Board.put(board, index, :o)

    %{c | board: board}
  end

  defp context_from_input(%{x: x, o: o})
       when is_reference(x) and is_reference(o) do
    %{x: x, o: o, winner: :none, board: %Board{}}
  end

  setup do
    x = make_ref()
    o = make_ref()
    input = %{x: x, o: o}

    [x: x, o: o, input: input]
  end

  test "checks if board has three siblings on same axis" do
    assert fill(%Board{}, {1, 2, 3}, :x) |> Board.won?(:x)
    assert fill(%Board{}, {4, 5, 6}, :x) |> Board.won?(:x)
    assert fill(%Board{}, {7, 8, 9}, :x) |> Board.won?(:x)

    assert fill(%Board{}, {1, 4, 7}, :x) |> Board.won?(:x)
    assert fill(%Board{}, {2, 5, 8}, :x) |> Board.won?(:x)
    assert fill(%Board{}, {3, 6, 9}, :x) |> Board.won?(:x)

    assert fill(%Board{}, {1, 5, 9}, :x) |> Board.won?(:x)
    assert fill(%Board{}, {3, 5, 7}, :x) |> Board.won?(:x)
  end

  test "checks if the current board is a draw" do
    refute Board.draw?(%Board{})
    refute fill(%Board{}, {1, 2, 3}, :x) |> Board.draw?()

    board = %Board{squares: {:x, :x, :o, :o, :o, :x, :x, :o, :x}}

    assert Board.draw?(board)
  end

  test "machine is updated when player x makes move", %{x: x, input: input} do
    machine =
      __MODULE__
      |> Machine.init(input: input)
      |> Machine.transition(%{type: :move, square: 3, ref: x})

    assert %Machine{state: :o, context: c} = machine
    assert Board.square(c.board, 3) == :x
  end

  test "machine is updated when player o makes move", %{x: x, o: o, input: input} do
    machine =
      __MODULE__
      |> Machine.init(input: input)
      |> Machine.transition(%{type: :move, square: 3, ref: x})
      |> Machine.transition(%{type: :move, square: 5, ref: o})

    assert %Machine{state: :x, context: c} = machine
    assert Board.square(c.board, 5) == :o
  end

  test "non-empty square can't be overriden", %{x: x, o: o, input: input} do
    machine =
      __MODULE__
      |> Machine.init(input: input)
      |> Machine.transition(%{type: :move, square: 3, ref: x})
      |> Machine.transition(%{type: :move, square: 3, ref: o})

    assert %Machine{state: :o, context: c} = machine
    assert Board.square(c.board, 3) == :x
  end

  test "transition to end when a player x wins", %{x: x, o: o, input: input} do
    machine = Machine.init(__MODULE__, input: input)

    events = [
      %{type: :move, ref: x, square: 5},
      %{type: :move, ref: o, square: 3},
      %{type: :move, ref: x, square: 6},
      %{type: :move, ref: o, square: 1},
      %{type: :move, ref: x, square: 4}
    ]

    machine = Enum.reduce(events, machine, &Machine.transition(&2, &1))

    assert %Machine{state: :end, context: %{winner: :x}} = machine
  end

  test "transition to end when a player o wins", %{x: x, o: o, input: input} do
    machine = Machine.init(__MODULE__, input: input)

    events = [
      %{type: :move, ref: x, square: 5},
      %{type: :move, ref: o, square: 3},
      %{type: :move, ref: x, square: 6},
      %{type: :move, ref: o, square: 1},
      %{type: :move, ref: x, square: 8},
      %{type: :move, ref: o, square: 2}
    ]

    machine = Enum.reduce(events, machine, &Machine.transition(&2, &1))

    assert %Machine{state: :end, context: %{winner: :o}} = machine
  end

  test "transition to end when the game is a draw", %{x: x, o: o, input: input} do
    machine = Machine.init(__MODULE__, input: input)

    events = [
      %{type: :move, ref: x, square: 5},
      %{type: :move, ref: o, square: 3},
      %{type: :move, ref: x, square: 6},
      %{type: :move, ref: o, square: 1},
      %{type: :move, ref: x, square: 2},
      %{type: :move, ref: o, square: 4},
      %{type: :move, ref: x, square: 9},
      %{type: :move, ref: o, square: 8},
      %{type: :move, ref: x, square: 7}
    ]

    machine = Enum.reduce(events, machine, &Machine.transition(&2, &1))

    assert %Machine{state: :end, context: %{winner: :none}} = machine
  end

  defp fill(%Board{} = board, {a, b, c}, tag) do
    board
    |> Board.put(a, tag)
    |> Board.put(b, tag)
    |> Board.put(c, tag)
  end
end
