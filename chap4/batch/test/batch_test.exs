defmodule BatchTest do
  use ExUnit.Case
  doctest Batch

  test "greets the world" do
    assert Batch.hello() == :world
  end
end
