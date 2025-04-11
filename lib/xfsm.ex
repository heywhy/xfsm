defmodule XFsm do
  @moduledoc """
  Documentation for `XFsm`.
  """

  @type context :: nil | map()
  @type callback :: fun() | atom() | %{required(:method) => atom(), optional(:params) => any()}
  @type event :: %{required(:type) => atom(), optional(atom()) => any()}
  @type self :: %{
          required(:pid) => nil | pid(),
          required(:state) => nil | atom()
        }
  @type action_arg :: %{
          optional(:event) => event(),
          required(:context) => context(),
          required(:self) => self()
        }
end
