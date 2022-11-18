defmodule Reactive.Persistence.InMemoryEventStore do
  @moduledoc """
  InMemoryEventStore is a `Reactive.Persistence.EventStore` 
  process used to store events for `Reactive.Entities.Entity` 
  instances in memory.
  """

  use Reactive.Persistence.EventStore

  defmodule State do
    @moduledoc """
    State is a struct that keeps all stored events in their streams.
    """

    defstruct streams: %{}
  end

  @doc """
  Initializes a InMemoryEventStore with a empty state.
  """
  def init(_) do
    {:ok, %State{streams: %{}}}
  end

  @doc """
  Load all events from a specific stream.
  """
  def load(id, %State{:streams => streams}) do
    case Map.get(streams, id) do
      nil -> []
      events -> events |> Enum.reverse()
    end
  end

  @doc """
  Appends a list of events to a stream. 
  If the stream doesn't exist it will be created.
  """
  def append(id, events, %State{:streams => streams} = state) do
    current_events =
      case Map.get(streams, id) do
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
