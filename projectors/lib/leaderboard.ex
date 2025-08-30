defmodule Projectors.Leaderboard do
  use GenServer
  require Logger

  def start_link() do
    GenServer.start_link(__MODULE__, nil)
  end

  def apply_event(pid, event) do
    GenServer.cast(pid, {:handle_event, event})
  end

  def get_top_10(pid) do
    GenServer.call(pid, :get_top_10)
  end

  def get_score(pid, attacker) do
    GenServer.call(pid, {:get_score, attacker})
  end

  @impl true
  def init(_) do
    {:ok, %{scores: %{}, top_10: []}}
  end

  @impl true
  def handle_call({:get_score, attacker}, _from, %{scores: scores} = state) do
    {:reply, Map.get(scores, attacker, 0), state}
  end

  @impl true
  def handle_call(:get_top_10, _from, %{top_10: top_10} = state) do
    {:reply, top_10, state}
  end

  @impl true
  def handle_cast({:handle_event, %{event_type: :zombie_killed, attacker: attacker}}, state) do
    scores = Map.update(state.scores, attacker, 1, &(&1 + 1))
    {:noreply, %{state | scores: scores, top_10: re_rank(scores)}}
  end

  @impl true
  def handle_cast({:handle_event, %{event_type: :week_completed}}, _state) do
    {:noreply, %{scores: %{}, top_10: []}}
  end

  defp re_rank(score) do
    score
    |> Map.to_list()
    |> Enum.sort(fn {_, a}, {_, b} -> a >= b end)
    |> Enum.take(10)
  end
end
