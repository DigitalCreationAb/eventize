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

  defmodule StoredEvent do
    @moduledoc """
    Represents a stored event.
    """

    defstruct [:type, :payload, :meta_data, :sequence_number]
  end

  def start_link(args) do
    GenServer.start_link(__MODULE__, :ok, args)
  end

  @doc """
  Initializes a InMemoryEventStore with a empty state.
  """
  def init(:ok) do
    {:ok, %State{streams: %{}}}
  end

  @doc """
  Load all events from a specific stream.
  """
  def load(id, start, max_count, %State{streams: streams}) do
    case Map.get(streams, id) do
      nil ->
        {:ok, 0, []}

      events ->
        latest_sequence_number =
          case events do
            [%StoredEvent{sequence_number: sequence_number} | _tail] -> sequence_number
            _ -> 0
          end

        deserialized_events =
          events
          |> Enum.map(fn event -> deserialize(event) end)
          |> Enum.reverse()
          |> Enum.filter(fn event ->
            case start do
              :start -> true
              position -> event.sequence_number >= position
            end
          end)

        deserialized_events =
          case max_count do
            :all -> deserialized_events
            count -> deserialized_events |> Enum.slice(0, count)
          end

        {:ok, latest_sequence_number, deserialized_events}
    end
  end

  @doc """
  Appends a list of events to a stream.
  If the stream doesn't exist it will be created.
  """
  def append(id, events, %State{streams: streams} = state, expected_version) do
    current_events =
      case Map.get(streams, id) do
        nil -> []
        events -> events
      end

    latest_sequence_number =
      case current_events do
        [%StoredEvent{sequence_number: sequence_number} | _tail] -> sequence_number
        _ -> 0
      end

    with :ok <- check_expected_version(latest_sequence_number, expected_version) do
      serialized_events =
        events
        |> Enum.with_index(latest_sequence_number + 1)
        |> Enum.map(fn {event, seq} -> serialize(event, seq) end)

      new_events = prepend(current_events, serialized_events)

      new_state = %State{
        state
        | streams: Map.put(streams, id, new_events)
      }

      version =
        case new_events do
          [] -> latest_sequence_number
          [head | _] -> head.sequence_number
          _ -> latest_sequence_number
        end

      {:ok, version, new_state}
    end
  end

  defp check_expected_version(current_version, expected_version) do
    case {current_version, expected_version} do
      {_, :any} ->
        :ok

      {version, version} ->
        :ok

      _ ->
        {:error,
         {:expected_version_missmatch,
          %{current_version: current_version, expected_version: expected_version}}}
    end
  end

  defp prepend(list, []), do: list
  defp prepend(list, [item | remainder]), do: prepend([item | list], remainder)

  defp serialize({{type, payload}, meta_data}, sequence_number) when is_atom(type) do
    %StoredEvent{
      type: type,
      payload: payload,
      sequence_number: sequence_number,
      meta_data: meta_data
    }
  end

  defp serialize({event, meta_data}, sequence_number) when is_struct(event) do
    %StoredEvent{
      type: event.__struct__,
      payload: event,
      sequence_number: sequence_number,
      meta_data: meta_data
    }
  end

  defp deserialize(%StoredEvent{
         payload: payload,
         meta_data: meta_data,
         sequence_number: sequence_number
       })
       when is_struct(payload) do
    %Reactive.Persistence.EventBus.EventData{
      payload: payload,
      meta_data: meta_data,
      sequence_number: sequence_number
    }
  end

  defp deserialize(%StoredEvent{
         type: type,
         payload: payload,
         meta_data: meta_data,
         sequence_number: sequence_number
       }) do
    %Reactive.Persistence.EventBus.EventData{
      payload: {type, payload},
      sequence_number: sequence_number,
      meta_data: meta_data
    }
  end
end
