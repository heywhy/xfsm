defmodule XFsm do
  @moduledoc """
  Documentation for `XFsm`.
  """

  @type context :: nil | map()
  @type callback :: fun() | atom() | %{required(:method) => atom(), optional(:params) => any()}
  @type event :: %{required(:type) => atom(), optional(atom()) => any()}
  @type action_arg :: %{
          optional(:event) => event(),
          required(:actor) => nil | pid(),
          required(:context) => context()
        }
end
