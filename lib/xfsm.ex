defmodule XFsm do
  @moduledoc """
  Documentation for `XFsm`.
  """

  @type callback :: fun() | atom() | %{required(:method) => atom(), optional(:params) => any()}
  @type event :: %{required(:type) => atom(), optional(atom()) => any()}
end
