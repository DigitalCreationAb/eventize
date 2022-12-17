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

    defstruct streams: %{},
              serializer: Reactive.Serialization.JasonSerializer
  end

  defmodule StoredEvent do
    @moduledoc """
    Represents a stored event.
    """

    defstruct [:type, :payload, :meta_data, :sequence_number]
  end

  @spec start_link(keyword) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    {start_opts, event_store_opts} =
      Keyword.split(opts, [:debug, :name, :timeout, :spawn_opt, :hibernate_after])

    case Keyword.fetch(event_store_opts, :serializer) do
      {:ok, serializer} -> GenServer.start_link(__MODULE__, %{serializer: serializer}, start_opts)
      _ -> GenServer.start_link(__MODULE__, :ok, start_opts)
    end
  end

  @spec init(%{:serializer => :atom} | term()) ::
          {:ok, %Reactive.Persistence.InMemoryEventStore.State{serializer: :atom, streams: map}}
  @doc """
  Initializes a InMemoryEventStore with a optional serializer.
  """
  def init(%{serializer: serializer}) do
    {:ok, %State{streams: %{}, serializer: serializer}}
  end

  def init(_) do
    {:ok, %State{streams: %{}}}
  end

  @spec load(
          String.t(),
          :start | non_neg_integer(),
          :all | non_neg_integer(),
          %Reactive.Persistence.InMemoryEventStore.State{
            serializer: :atom,
            streams: map
          }
        ) :: {:ok, non_neg_integer(), list(Reactive.Persistence.EventBus.EventData)}
  @doc """
  Load all events from a specific stream.
  """
  def load(stream_name, start, max_count, %State{streams: streams, serializer: serializer}) do
    case Map.get(streams, stream_name) do
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
          |> Enum.map(fn event -> deserialize(event, serializer) end)
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

  @spec append(
          String.t(),
          list({event :: term(), meta_data :: map()}),
          %Reactive.Persistence.InMemoryEventStore.State{
            serializer: :atom,
            streams: map
          },
          :any | non_neg_integer()
        ) ::
          {:error,
           {:expected_version_missmatch,
            %{current_version: non_neg_integer(), expected_version: non_neg_integer()}}}
          | {:ok, non_neg_integer(),
             %Reactive.Persistence.InMemoryEventStore.State{
               serializer: :atom,
               streams: map
             }}
  @doc """
  Appends a list of events to a stream.
  If the stream doesn't exist it will be created.
  """
  def append(
        stream_name,
        events,
        %State{streams: streams, serializer: serializer} = state,
        expected_version
      ) do
    current_events =
      case Map.get(streams, stream_name) do
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
        |> Enum.map(fn {event, seq} -> serialize(event, seq, serializer) end)

      new_events = prepend(current_events, serialized_events)

      new_state = %State{
        state
        | streams: Map.put(streams, stream_name, new_events)
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

  @spec delete(String.t(), non_neg_integer(), %Reactive.Persistence.InMemoryEventStore.State{
          :streams => map
        }) ::
          :ok
          | {:ok, %Reactive.Persistence.InMemoryEventStore.State{:streams => map}}
  def delete(stream_name, version, %State{streams: streams} = state) do
    case Map.get(streams, stream_name) do
      nil ->
        :ok

      events ->
        new_events =
          events
          |> Enum.filter(fn event -> event.sequence_number > version end)

        {:ok, %State{state | streams: Map.put(streams, stream_name, new_events)}}
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

  defp serialize({{type, payload}, meta_data}, sequence_number, serializer) when is_atom(type) do
    with {:ok, serialized_payload} <- serializer.serialize(payload),
         {:ok, serialized_meta_data} <- serializer.serialize(meta_data) do
      %StoredEvent{
        type: nil,
        payload: {type, serialized_payload},
        sequence_number: sequence_number,
        meta_data: serialized_meta_data
      }
    end
  end

  defp serialize({event, meta_data}, sequence_number, serializer) when is_struct(event) do
    with {:ok, serialized_payload} <- serializer.serialize(event),
         {:ok, serialized_meta_data} <- serializer.serialize(meta_data) do
      %StoredEvent{
        type: event.__struct__,
        payload: serialized_payload,
        sequence_number: sequence_number,
        meta_data: serialized_meta_data
      }
    end
  end

  defp deserialize(
         %StoredEvent{
           type: nil,
           payload: {type, payload},
           meta_data: meta_data,
           sequence_number: sequence_number
         },
         serializer
       ) do
    with {:ok, deserialized_payload} <- serializer.deserialize(payload),
         {:ok, deserialized_meta_data} <- serializer.deserialize(meta_data) do
      %Reactive.Persistence.EventBus.EventData{
        payload: {type, deserialized_payload},
        meta_data: deserialized_meta_data,
        sequence_number: sequence_number
      }
    end
  end

  defp deserialize(
         %StoredEvent{
           type: type,
           payload: payload,
           meta_data: meta_data,
           sequence_number: sequence_number
         },
         serializer
       ) do
    with {:ok, deserialized_payload} <- serializer.deserialize(payload, type),
         {:ok, deserialized_meta_data} <- serializer.deserialize(meta_data) do
      %Reactive.Persistence.EventBus.EventData{
        payload: deserialized_payload,
        meta_data: deserialized_meta_data,
        sequence_number: sequence_number
      }
    end
  end
end
