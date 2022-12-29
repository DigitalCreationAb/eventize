defmodule Eventize.Persistence.InMemoryEventStore do
  @moduledoc """
  InMemoryEventStore is a `Eventize.Persistence.EventStore`
  process used to store events for `Eventize.Entities.Entity`
  instances in memory.
  """
  alias Eventize.Persistence.EventStore.SnapshotData

  use Eventize.Persistence.EventStore

  defmodule State do
    @moduledoc """
    State is a struct that keeps all stored events in their streams.
    """

    defstruct streams: %{},
              snapshots: %{},
              serializer: Eventize.Serialization.JasonSerializer
  end

  defmodule StoredEvent do
    @moduledoc """
    Represents a stored event.
    """

    defstruct [:type, :payload, :meta_data, :sequence_number]
  end

  defmodule StoredSnapshot do
    @moduledoc """
    Represents a stored snapshot.
    """

    defstruct [:type, :payload, :meta_data, :version]
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

  @spec init(%{serializer: :atom} | term()) ::
          {:ok, Eventize.Persistence.InMemoryEventStore.State.t()}
  @doc """
  Initializes a InMemoryEventStore with a optional serializer.
  """
  def init(%{serializer: serializer}) do
    {:ok, %State{streams: %{}, snapshots: %{}, serializer: serializer}}
  end

  def init(_) do
    {:ok, %State{streams: %{}, snapshots: %{}}}
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
    events =
      case Map.get(streams, stream_name) do
        nil -> []
        e -> e
      end

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

    {:reply, {:ok, latest_sequence_number, deserialized_events}, state}
  end

  def append_events(
        %{stream_name: stream_name, events: events, expected_version: expected_version},
        _from,
        %State{streams: streams, serializer: serializer} = state
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

    case check_expected_version(latest_sequence_number, expected_version) do
      :ok ->
        serialized_events =
          events
          |> Enum.with_index(latest_sequence_number + 1)
          |> Enum.map(fn {event, seq} -> serialize(event, seq, serializer, :event) end)

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

        {:reply,
         {:ok, version,
          serialized_events |> Enum.map(fn event -> deserialize(event, serializer) end)},
         new_state}

      err ->
        {:reply, err, state}
    end
  end

  def delete_events(
        %{stream_name: stream_name, version: version},
        _from,
        %State{streams: streams} = state
      ) do
    case Map.get(streams, stream_name) do
      nil ->
        {:reply, :ok, state}

      events ->
        new_events =
          events
          |> Enum.filter(fn event -> event.sequence_number > version end)

        {:reply, :ok, %State{state | streams: Map.put(streams, stream_name, new_events)}}
    end
  end

  def load_snapshot(
        %{
          stream_name: stream_name,
          max_version: max_version
        },
        _from,
        %State{snapshots: snapshots_data, serializer: serializer} = state
      ) do
    snapshots =
      case Map.get(snapshots_data, stream_name) do
        nil -> []
        ss -> ss
      end
      |> Enum.filter(fn snapshot ->
        snapshot.version <= max_version
      end)
      |> Enum.take(1)

    case snapshots do
      [snapshot | _] -> {:reply, {:ok, deserialize(snapshot, serializer)}, state}
      _ -> {:reply, {:ok, nil}, state}
    end
  end

  def append_snapshot(
        %{
          stream_name: stream_name,
          snapshot: snapshot,
          version: version,
          expected_version: expected_version
        },
        _from,
        %State{snapshots: snapshots, streams: streams, serializer: serializer} = state
      ) do
    current_snapshots =
      case Map.get(snapshots, stream_name) do
        nil -> []
        s -> s
      end

    current_events =
      case Map.get(streams, stream_name) do
        nil -> []
        e -> e
      end

    latest_sequence_number =
      case current_events do
        [%StoredEvent{sequence_number: sequence_number} | _tail] -> sequence_number
        _ -> 0
      end

    case check_expected_version(latest_sequence_number, expected_version) do
      :ok ->
        serialized_snapshot = serialize(snapshot, version, serializer, :snapshot)

        new_snapshots = [serialized_snapshot | current_snapshots]

        new_state = %State{
          state
          | snapshots: Map.put(snapshots, stream_name, new_snapshots)
        }

        {:reply, {:ok, deserialize(serialized_snapshot, serializer)}, new_state}

      err ->
        {:reply, err, state}
    end
  end

  def delete_snapshots(
        %{stream_name: stream_name, version: version},
        _from,
        %State{snapshots: snapshots} = state
      ) do
    case Map.get(snapshots, stream_name) do
      nil ->
        {:reply, :ok, state}

      items ->
        new_snapshots =
          items
          |> Enum.filter(fn snapshot -> snapshot.version > version end)

        {:reply, :ok, %State{state | snapshots: Map.put(snapshots, stream_name, new_snapshots)}}
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

  defp serialize({{type, payload}, meta_data}, sequence_number, serializer, :event)
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

  defp serialize({event, meta_data}, sequence_number, serializer, :event) when is_struct(event) do
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

  defp serialize({{type, payload}, meta_data}, version, serializer, :snapshot)
       when is_atom(type) do
    with {:ok, serialized_payload} <- serializer.serialize(payload),
         {:ok, serialized_meta_data} <- serializer.serialize(meta_data) do
      %StoredSnapshot{
        type: nil,
        payload: {type, serialized_payload},
        version: version,
        meta_data: serialized_meta_data
      }
    end
  end

  defp serialize({snapshot, meta_data}, version, serializer, :snapshot)
       when is_struct(snapshot) do
    with {:ok, serialized_payload} <- serializer.serialize(snapshot),
         {:ok, serialized_meta_data} <- serializer.serialize(meta_data) do
      %StoredSnapshot{
        type: snapshot.__struct__,
        payload: serialized_payload,
        version: version,
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
         serializer
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
         %StoredSnapshot{
           type: nil,
           payload: {type, payload},
           meta_data: meta_data,
           version: version
         },
         serializer
       ) do
    with {:ok, deserialized_payload} <- serializer.deserialize(payload),
         {:ok, deserialized_meta_data} <- serializer.deserialize(meta_data) do
      %SnapshotData{
        payload: {type, deserialized_payload},
        meta_data: deserialized_meta_data,
        version: version
      }
    end
  end

  defp deserialize(
         %StoredSnapshot{
           type: type,
           payload: payload,
           meta_data: meta_data,
           version: version
         },
         serializer
       ) do
    with {:ok, deserialized_payload} <- serializer.deserialize(payload, type),
         {:ok, deserialized_meta_data} <- serializer.deserialize(meta_data) do
      %SnapshotData{
        payload: deserialized_payload,
        meta_data: deserialized_meta_data,
        version: version
      }
    end
  end
end
