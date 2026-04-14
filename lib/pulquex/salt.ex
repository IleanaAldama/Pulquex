defmodule Pulquex.Salt do
  def new(len \\ 128) do
    len
    |> div(2)
    |> :crypto.strong_rand_bytes()
    |> Base.encode16(case: :lower)
  end
end
