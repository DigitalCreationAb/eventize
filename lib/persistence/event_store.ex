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
  @type delete_events_command :: %{stream_name: String.t(), version: non_neg_integer()}

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
  @type delete_snapshots_command :: %{stream_name: String.t(), version: non_neg_integer()}

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
