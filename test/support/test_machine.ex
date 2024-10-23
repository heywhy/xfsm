defmodule XFsm.TestMachine do
  @moduledoc false

  use XFsm.Builder

  initial(:l1)

  context %{input: input} do
    %{name: input.name}
  end

  # context(%{name: nil})

  # context do
  #   # %{name: 2}
  #   Application.get_all_env(:kyx)
  # end

  state :l1 do
    exit(:persist)
    entry(:nill)

    on(:upgrade, target: :l2, guard: :can_upgrade, action: :assigns)

    on :downgrade do
      target(:l3)
      action(:update)
      guard(:can_downgrade)
    end

    on :slowdown do
      target(:l4)

      action context do
        a = 1
        b = 2

        context.total + a + b
      end
    end
  end

  state :l2 do
    exit(:persist)

    on :upgrade do
      target(:l3)

      action context do
        Map.put(context, :lowkey, 1)
      end

      guard do
      end
    end

    on :upgrade do
      action(:persist)

      guard do
      end
    end
  end

  state :l3 do
    exit(:persist)

    on :upgrade do
      target(:l3)

      action arg do
        Map.put(arg, :lowkey, 2)
      end

      guard do
      end
    end
  end

  # action :update do
  # end
  #
  # action :persist do
  # end
end
