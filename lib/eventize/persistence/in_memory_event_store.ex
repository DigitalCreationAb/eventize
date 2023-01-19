defmodule Eventize.Persistence.InMemoryEventStore do
  @moduledoc """
  InMemoryEventStore is a `Eventize.Persistence.EventStore`
  process used to store events for `EventizeEntity`
  instances in memory.
  """

  alias Eventize.Persistence.EventStore.SnapshotData

  use Eventize.Persistence.EventStore

  defmodule State do
    @moduledoc false

    @type t :: %__MODULE__{streams: map(), serializer: atom}

    defstruct streams: %{},
              serializer: Eventize.Serialization.JasonSerializer
  end

  defmodule StreamData do
    @moduledoc false

    @type t :: %__MODULE__{
            events: list(),
            snapshots: list(),
            sequence_number: :empty | non_neg_integer()
          }

    defstruct events: [],
              snapshots: [],
              sequence_number: :empty
  end

  defmodule StoredEvent do
    @moduledoc false

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

  @spec init(%{serializer: atom} | term()) ::
          {:ok, Eventize.Persistence.InMemoryEventStore.State.t()}
  @doc """
  Initializes a InMemoryEventStore with a optional serializer.
  """
  def init(%{serializer: serializer}) do
    {:ok, %State{serializer: serializer}}
  end

  def init(_) do
    {:ok, %State{}}
  end

  def load_events(
        %{
          stream_name: stream_name,
          start: start,
          max_count: max_count
        },
        _from,
        %State{streams: streams, serializer: serializer} = state
      ) do
    %StreamData{events: events, sequence_number: sequence_number} =
      case Map.get(streams, stream_name) do
        nil -> %StreamData{}
        s -> s
      end

    deserialized_events =
      events
      |> Enum.map(fn event -> deserialize(event, serializer, :event) end)
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

    {:reply, {:ok, deserialized_events, sequence_number}, state}
  end

  def append_events(
        %{stream_name: stream_name, events: events, expected_version: expected_version},
        _from,
        %State{streams: streams, serializer: serializer} = state
      ) do
    stream =
      case Map.get(streams, stream_name) do
        nil -> %StreamData{}
        s -> s
      end

    %StreamData{events: current_events, sequence_number: latest_sequence_number} = stream

    case check_expected_version(latest_sequence_number, expected_version) do
      :ok ->
        serialized_events =
          events
          |> Enum.with_index(
            case latest_sequence_number do
              :empty -> 0
              i -> i + 1
            end
          )
          |> Enum.map(fn {event, seq} -> serialize(event, seq, serializer) end)

        new_events = prepend(current_events, serialized_events)

        new_sequence_number =
          new_events
          |> Enum.reverse()
          |> Enum.reduce(latest_sequence_number, fn %StoredEvent{sequence_number: sequence_number},
                                                    _ ->
            sequence_number
          end)

        new_state = %State{
          state
          | streams:
              Map.put(streams, stream_name, %StreamData{
                stream
                | events: new_events,
                  sequence_number: new_sequence_number
              })
        }

        {:reply,
         {:ok,
          serialized_events |> Enum.map(fn event -> deserialize(event, serializer, :event) end),
          new_sequence_number}, new_state}

      err ->
        {:reply, err, state}
    end
  end

  def delete_events(
        %{stream_name: stream_name, version: version},
        _from,
        %State{streams: streams} = state
      ) do
    stream =
      case Map.get(streams, stream_name) do
        nil -> %StreamData{}
        s -> s
      end

    %StreamData{events: events} = stream

    new_events =
      events
      |> Enum.filter(fn event -> !should_remove(event, version) end)

    {:reply, :ok,
     %State{
       state
       | streams: Map.put(streams, stream_name, %StreamData{stream | events: new_events})
     }}
  end

  def load_snapshot(
        %{
          stream_name: stream_name,
          max_version: max_version
        },
        _from,
        %State{streams: streams, serializer: serializer} = state
      ) do
    stream =
      case Map.get(streams, stream_name) do
        nil -> %StreamData{}
        s -> s
      end

    %StreamData{snapshots: snapshots} = stream

    snapshots =
      snapshots
      |> Enum.filter(fn snapshot ->
        snapshot.sequence_number <= max_version
      end)
      |> Enum.take(1)

    case snapshots do
      [snapshot | _] -> {:reply, {:ok, deserialize(snapshot, serializer, :snapshot)}, state}
      _ -> {:reply, {:ok, nil}, state}
    end
  end

  def append_snapshot(
        %{
          stream_name: stream_name,
          snapshot: snapshot,
          version: version
        },
        _from,
        %State{streams: streams, serializer: serializer} = state
      ) do
    stream =
      case Map.get(streams, stream_name) do
        nil -> %StreamData{}
        s -> s
      end

    %StreamData{snapshots: current_snapshots} = stream

    serialized_snapshot = serialize(snapshot, version, serializer)

    new_snapshots = [serialized_snapshot | current_snapshots]

    new_state = %State{
      state
      | streams: Map.put(streams, stream_name, %StreamData{stream | snapshots: new_snapshots})
    }

    {:reply, {:ok, deserialize(serialized_snapshot, serializer, :snapshot)}, new_state}
  end

  def delete_snapshots(
        %{stream_name: stream_name, version: version},
        _from,
        %State{streams: streams} = state
      ) do
    stream =
      case Map.get(streams, stream_name) do
        nil -> %StreamData{}
        s -> s
      end

    %StreamData{snapshots: snapshots} = stream

    new_snapshots =
      snapshots
      |> Enum.filter(fn snapshot -> !should_remove(snapshot, version) end)

    {:reply, :ok,
     %State{
       state
       | streams: Map.put(streams, stream_name, %StreamData{stream | snapshots: new_snapshots})
     }}
  end

  defp should_remove(%StoredEvent{sequence_number: event_sequence_number}, new_version) do
    case new_version do
      :all ->
        true

      version ->
        event_sequence_number <= version
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

  defp serialize({{type, payload}, meta_data}, sequence_number, serializer)
       when is_atom(type) do
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
         serializer,
         :event
       ) do
    with {:ok, deserialized_payload} <- serializer.deserialize(payload),
         {:ok, deserialized_meta_data} <- serializer.deserialize(meta_data) do
      %EventData{
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
         serializer,
         :event
       ) do
    with {:ok, deserialized_payload} <- serializer.deserialize(payload, type),
         {:ok, deserialized_meta_data} <- serializer.deserialize(meta_data) do
      %EventData{
        payload: deserialized_payload,
        meta_data: deserialized_meta_data,
        sequence_number: sequence_number
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
         serializer,
         :snapshot
       ) do
    with {:ok, deserialized_payload} <- serializer.deserialize(payload),
         {:ok, deserialized_meta_data} <- serializer.deserialize(meta_data) do
      %SnapshotData{
        payload: {type, deserialized_payload},
        meta_data: deserialized_meta_data,
        version: sequence_number
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
         serializer,
         :snapshot
       ) do
    with {:ok, deserialized_payload} <- serializer.deserialize(payload, type),
         {:ok, deserialized_meta_data} <- serializer.deserialize(meta_data) do
      %SnapshotData{
        payload: deserialized_payload,
        meta_data: deserialized_meta_data,
        version: sequence_number
      }
    end
  end
end
