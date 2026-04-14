defmodule PulquexTest do
  use ExUnit.Case
  doctest Pulquex

  test "greets the world" do
    assert Pulquex.hello() == :world
  end
end
