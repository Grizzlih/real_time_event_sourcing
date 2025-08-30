defmodule FlightTracker.CraftProjector do
  require Logger
  use GenStage
  alias FlightTracker.MessageBroadcaster

  def start_link(_) do
    GenStage.start_link(__MODULE__, :ok)
  end

  def init(:ok) do
    :ets.new(:aircraft_table, [:named_table, :set, :public])
    {:consumer, :ok, subscribe_to: [MessageBroadcaster]}
  end

  def handle_events(events, _from, state) do
    for event <- events do
      handle_event(Cloudevents.from_json!(event))
    end

    {:noreply, [], state}
  end

  defp handle_event(%Cloudevents.Format.V_1_0.Event{
         type: "org.book.flighttracker.aircraft_identified",
         data: data
       }) do
    old_state = get_state_by_icao(data["icao_address"])

    :ets.insert(
      :aircraft_table,
      {
        data["icao_address"],
        Map.put(old_state, :callsign, data["callsign"])
      }
    )
  end

  defp handle_event(%Cloudevents.Format.V_1_0.Event{
         type: "org.book.flighttracker.velocity_reported",
         data: data
       }) do
    old_state = get_state_by_icao(data["icao_address"])

    new_state =
      old_state
      |> Map.put(:heading, data["heading"])
      |> Map.put(:ground_speed, data["ground_speed"])
      |> Map.put(:vertical_rate, data["vertical_rate"])

    :ets.insert(:aircraft_table, {data["icao_address"], new_state})
  end

  defp handle_event(%Cloudevents.Format.V_1_0.Event{
         type: "org.book.flighttracker.position_reported",
         data: data
       }) do
    old_state = get_state_by_icao(data["icao_address"])

    new_state =
      old_state
      |> Map.put(:altitude, data["altitude"])
      |> Map.put(:latitude, data["latitude"])
      |> Map.put(:longitude, data["longitude"])

    :ets.insert(:aircraft_table, {data["icao_address"], new_state})
  end

  defp handle_event(_) do
  end

  def get_state_by_icao(icao) do
    case :ets.lookup(:aircraft_table, icao) do
      [{_, state}] -> state
      [] -> %{icao_address: icao}
    end
  end

  def aircraft_by_callsign(callsign) do
    :ets.select(:aircraft_table, [
      {
        {:"$1", :"$2"},
        [
          {:==, {:map_get, :callsign, :"$2"}, callsign}
        ],
        [:"$2"]
      }
    ])
    |> List.first()
  end
end
