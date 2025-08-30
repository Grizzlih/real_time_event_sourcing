defmodule FlightTracker.MessageBroadcaster do
  use GenStage
  require Logger

  def start_link(_) do
    GenStage.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  @doc """
  Injects a raw message that is not in cloud event format
  """
  def broadcast_message(message) do
    GenStage.call(__MODULE__, {:notify_message, message})
  end

  @doc """
  Injects a cloud event to be published to the stage pipeline
  """
  def broadcast_event(event) do
    GenStage.call(__MODULE__, {:notify_event, event})
  end

  @impl true
  def init(:ok) do
    {:producer, :ok, dispatcher: GenStage.BroadcastDispatcher}
  end

  @impl true
  def handle_call({:notify_message, message}, _from, state) do
    {:reply, :ok, [message |> to_event()], state}
  end

  @impl true
  def handle_call({:notify_event, event}, _from, state) do
    {:reply, :ok, [event], state}
  end

  @impl true
  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end

  defp to_event(%{
         type: :aircraft_identified,
         message: %{icao_address: _, callsign: _, emitter_category: _} = message
       }) do
    new_cloudevent("aircraft_identified", message)
  end

  defp to_event(%{
         type: :squawk_received,
         message: %{squawk: _, icao_address: _} = message
       }) do
    new_cloudevent("squawk_received", message)
  end

  defp to_event(%{
         type: :position_reported,
         message: %{
           icao_address: icao,
           position: %{
             altitude: alt,
             latitude: lat,
             longitude: lon
           }
         }
       }) do
    new_cloudevent("position_reported", %{
      altitude: alt,
      latitude: lat,
      longitude: lon,
      icao_address: icao
    })
  end

  defp to_event(%{
         type: :velocity_reported,
         message:
           %{
             heading: _,
             ground_speed: _,
             vertical_rate: _,
             vertical_rate_source: vertical_rate_source
           } = message
       }) do
    source =
      case vertical_rate_source do
        :barometric_pressure -> "barometric"
        :geometric -> "geometric"
        _ -> "unknown"
      end

    new_cloudevent("velocity_reported", %{message | vertical_rate_source: source})
  end

  defp to_event(message) do
    Logger.error("Unknown message: #{inspect(message)}")
    %{}
  end

  defp new_cloudevent(type, data) do
    %{
      "specversion" => "1.0",
      "type" => "org.book.flighttracker.#{String.downcase(type)}",
      "source" => "radio_aggregator",
      "id" => UUID.uuid4(),
      "time" => DateTime.utc_now() |> DateTime.to_iso8601(),
      "data" => data
    }
    |> Cloudevents.from_map!()
    |> Cloudevents.to_json()
  end
end
