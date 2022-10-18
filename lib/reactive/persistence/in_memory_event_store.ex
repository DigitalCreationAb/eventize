defmodule Reactive.Persistence.InMemoryEventStore do
  use Reactive.Persistence.EventStore

  defmodule State do
    defstruct streams: %{}
  end
  
  def init(_) do
    {:ok, %State{streams: %{}}}
  end
  
  def load(id, %State{:streams => streams}) do
    case Map.get(streams, id) do
      nil -> []
      events -> events |> Enum.reverse()
    end
  end
  
  def append(id, events, %State{:streams => streams} = state) do
    current_events = case Map.get(streams, id) do
      nil -> []
      events -> events
    end
    
    new_events = prepend(current_events, events)
    
    new_state = %State{
      state 
      | streams: Map.put(streams, id, new_events)
    }

    {:ok, new_state}
  end

  defp prepend(list, []), do: list
  defp prepend(list, [item | remainder]), do: prepend([item | list], remainder)
end
