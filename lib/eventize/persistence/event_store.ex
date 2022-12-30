defmodule Eventize.Persistence.EventStore do
  @moduledoc """
  EventStore is a `GenServer` process used to store
  events for `Eventize.Entities.Entity` instances.
  """

  defmodule EventData do
    @moduledoc """
    Represents a event with payload, meta data and a sequence number.
    """

    defstruct [:payload, :meta_data, :sequence_number]
  end

  defmodule SnapshotData do
    @moduledoc """
    Represents a snapshot with payload, meta data and version.
    """

    defstruct [:payload, :meta_data, :version]
  end

  @typedoc """
  A map containing all data needed to get events from the event store.
  """
  @type load_events_query :: %{
          stream_name: String.t(),
          start: :start | non_neg_integer(),
          max_count: :all | non_neg_integer()
        }

  @typedoc """
  A map containing all data needed to append events to the event store.
  """
  @type append_events_command :: %{
          stream_name: String.t(),
          events: list({term(), map()}),
          expected_version: :any | non_neg_integer()
        }

  @typedoc """
  A map containing all data needed to delete events from the event store.
  """
  @type delete_events_command :: %{stream_name: String.t(), version: non_neg_integer() | :all}

  @typedoc """
  A map containing all data needed to load a snapshot from the event store.
  """
  @type load_snapshot_query :: %{
          stream_name: String.t(),
          max_version: :max | non_neg_integer()
        }

  @typedoc """
  A map containing all data needed to append a snapshot to the event store.
  """
  @type append_snapshot_command :: %{
          stream_name: String.t(),
          snapshot: {term(), map()},
          version: non_neg_integer(),
          expected_version: :any | non_neg_integer()
        }

  @typedoc """
  A map containing all data needed to delete snapshots from the event store.
  """
  @type delete_snapshots_command :: %{stream_name: String.t(), version: non_neg_integer() | :all}

  @typedoc """
  Represents the response that a caller will receive when reading or appending events.
  """
  @type events_response :: {:ok, non_neg_integer(), list(EventData)} | {:error, term()}

  @typedoc """
  Represents the response that a caller will receive when reading or appending a snapshot.
  """
  @type snapshot_response :: {:ok, %SnapshotData{} | nil} | {:error, term()}

  @typedoc """
  Represents the response a caller will receive when deleting events or snapshots.
  """
  @type delete_response :: :ok | {:error, term()}

  @type event_bus :: %{
          load_events:
            (String.t(), :start | non_neg_integer(), :all | non_neg_integer() ->
               events_response()),
          append_events:
            (String.t(), list({term(), map()}), non_neg_integer() -> events_response()),
          delete_events: (String.t(), non_neg_integer() -> delete_response()),
          load_snapshot: (String.t(), :max | non_neg_integer() -> snapshot_response()),
          append_snapshot:
            (String.t(), {term(), map()}, non_neg_integer(), :any | non_neg_integer() ->
               snapshot_response()),
          delete_snapshots: (String.t(), non_neg_integer() -> delete_response())
        }

  @callback load_events(
              load_events_query(),
              GenServer.from(),
              term()
            ) ::
              {:reply, events_response(), term()}
              | {:reply, events_response(), term(),
                 timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | {:stop, term(), term(), term()}
              | {:stop, term(), term()}

  @callback append_events(append_events_command(), GenServer.from(), term()) ::
              {:reply, events_response(), term()}
              | {:reply, events_response(), term(),
                 timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | {:stop, term(), term(), term()}
              | {:stop, term(), term()}

  @callback delete_events(delete_events_command(), GenServer.from(), term()) ::
              {:reply, delete_response(), term()}
              | {:reply, delete_response(), term(),
                 timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | {:stop, term(), term(), term()}
              | {:stop, term(), term()}

  @callback load_snapshot(load_snapshot_query(), GenServer.from(), term()) ::
              {:reply, snapshot_response(), term()}
              | {:reply, snapshot_response(), term(),
                 timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | {:stop, term(), term(), term()}
              | {:stop, term(), term()}

  @callback append_snapshot(append_snapshot_command(), GenServer.from(), term()) ::
              {:reply, snapshot_response(), term()}
              | {:reply, snapshot_response(), term(),
                 timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | {:stop, term(), term(), term()}
              | {:stop, term(), term()}

  @callback delete_snapshots(
              delete_snapshots_command(),
              GenServer.from(),
              term()
            ) ::
              {:reply, delete_response(), term()}
              | {:reply, delete_response(), term(),
                 timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | {:stop, term(), term(), term()}
              | {:stop, term(), term()}

  defguardp is_event_bus(event_bus)
            when is_map(event_bus) and is_map_key(event_bus, :load_events) and
                   is_map_key(event_bus, :append_events) and
                   is_map_key(event_bus, :delete_events) and
                   is_map_key(event_bus, :load_snapshot) and
                   is_map_key(event_bus, :append_snapshot) and
                   is_map_key(event_bus, :delete_snapshots) and
                   is_function(event_bus.load_events, 3) and
                   is_function(event_bus.append_events, 3) and
                   is_function(event_bus.delete_events, 2) and
                   is_function(event_bus.load_snapshot, 2) and
                   is_function(event_bus.append_snapshot, 4) and
                   is_function(event_bus.delete_snapshots, 2)

  @spec parse_event_bus(any) :: event_bus()
  def parse_event_bus(bus) do
    case bus do
      nil ->
        Eventize.Persistence.NilEventBus.get()

      eb when is_event_bus(eb) ->
        eb

      pid ->
        %{
          load_events: fn stream_name, start, max_count ->
            GenServer.call(
              pid,
              {:load_events,
               %{
                 stream_name: stream_name,
                 start: start,
                 max_count: max_count
               }}
            )
          end,
          append_events: fn stream_name, events, expected_version ->
            GenServer.call(
              pid,
              {:append_events,
               %{
                 stream_name: stream_name,
                 events: events,
                 expected_version: expected_version
               }}
            )
          end,
          delete_events: fn stream_name, version ->
            GenServer.call(
              pid,
              {:delete_events, %{stream_name: stream_name, version: version}}
            )
          end,
          load_snapshot: fn stream_name, max_version ->
            GenServer.call(
              pid,
              {:load_snapshot, %{stream_name: stream_name, max_version: max_version}}
            )
          end,
          append_snapshot: fn stream_name, snapshot, version, expected_version ->
            GenServer.call(
              pid,
              {:append_snapshot,
               %{
                 stream_name: stream_name,
                 snapshot: snapshot,
                 version: version,
                 expected_version: expected_version
               }}
            )
          end,
          delete_snapshots: fn stream_name, version ->
            GenServer.call(
              pid,
              {:delete_snapshots, %{stream_name: stream_name, version: version}}
            )
          end
        }
    end
  end

  defmacro __using__(_) do
    quote do
      use GenServer

      @behaviour Eventize.Persistence.EventStore
      alias Eventize.Persistence.EventStore.EventData

      def handle_call({:load_events, query}, from, state),
        do: load_events(query, from, state)

      def handle_call({:append_events, cmd}, from, state),
        do: append_events(cmd, from, state)

      def handle_call({:delete_events, cmd}, from, state),
        do: delete_events(cmd, from, state)

      def handle_call({:load_snapshot, query}, from, state),
        do: load_snapshot(query, from, state)

      def handle_call({:append_snapshot, cmd}, from, state),
        do: append_snapshot(cmd, from, state)

      def handle_call({:delete_snapshots, cmd}, from, state),
        do: delete_snapshots(cmd, from, state)
    end
  end
end
