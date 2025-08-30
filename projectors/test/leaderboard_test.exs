defmodule LeaderboardTest do
  use ExUnit.Case
  alias Projectors.Leaderboard

  test "leaderboard projection" do
    {:ok, pid} = Leaderboard.start_link()

    Leaderboard.apply_event(pid, %{event_type: :zombie_killed, attacker: "Bob"})
    Leaderboard.apply_event(pid, %{event_type: :zombie_killed, attacker: "Bob"})
    Leaderboard.apply_event(pid, %{event_type: :zombie_killed, attacker: "John"})

    assert Leaderboard.get_top_10(pid) == [{"Bob", 2}, {"John", 1}]
    assert Leaderboard.get_score(pid, "Bob") == 2
    assert Leaderboard.get_score(pid, "John") == 1
    assert Leaderboard.get_score(pid, "Alice") == 0

    Leaderboard.apply_event(pid, %{event_type: :week_completed})

    assert Leaderboard.get_top_10(pid) == []
    assert Leaderboard.get_score(pid, "Bob") == 0
    assert Leaderboard.get_score(pid, "John") == 0
    assert Leaderboard.get_score(pid, "Alice") == 0
  end
end
