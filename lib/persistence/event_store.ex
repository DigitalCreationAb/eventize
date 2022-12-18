defmodule Reactive.Persistence.EventStore do
  @moduledoc """
  EventStore is a `GenServer` process used to store
  events for `Reactive.Entities.Entity` instances.
  """

  alias Reactive.Persistence.EventBus.EventData

  @doc """
  A callback used to load all the events for a stream.
  """
  @callback load(
              stream_name :: String.t(),
              start :: :start | non_neg_integer(),
              max_count :: :all | non_neg_integer(),
              state :: map()
            ) ::
              {:ok, version :: non_neg_integer(), events :: list(EventData), new_state :: map()}
              | {:ok, version :: non_neg_integer(), events :: list(EventData)}
              | {:error, term(), new_state :: map()}
              | {:error, term()}

  @doc """
  A callback used to append new events to a stream.
  """
  @callback append(
              stream_name :: String.t(),
              events :: list({event :: term(), meta_data :: map()}),
              state :: map(),
              expected_version :: :any | non_neg_integer()
            ) ::
              {:ok, version :: non_neg_integer(),
               events :: list(Reactive.Persistence.EventBus.EventData), new_state :: map()}
              | {:ok, version :: non_neg_integer(),
                 events :: list(Reactive.Persistence.EventBus.EventData)}
              | {:error, term(), new_state :: map()}
              | {:error, term()}

  @callback delete(stream_name :: String.t(), version :: non_neg_integer(), state :: map()) ::
              :ok | {:ok, new_state :: map()} | {:error, term(), map()} | {:error, term()}

  defmodule AppendCommand do
    @moduledoc """
    Defines a append command struct.
    """

    defstruct [:stream_name, :events, :expected_version]
  end

  defmodule LoadQuery do
    @moduledoc """
    Defines a load query struct.
    """

    defstruct [:stream_name, :start, :max_count]
  end

  defmacro __using__(_) do
    quote do
      use GenServer

      @behaviour Reactive.Persistence.EventStore

      @doc """
      Loads all events for a stream.
      """
      def handle_call(
            %LoadQuery{stream_name: stream_name, start: start, max_count: max_count},
            _from,
            state
          ) do
        case load(stream_name, start, max_count, state) do
          {:ok, version, events, new_state} ->
            {:reply, {:ok, version, events}, new_state}

          {:ok, version, events} ->
            {:reply, {:ok, version, events}, state}

          {:error, error, new_state} ->
            {:reply, {:error, error}, new_state}

          {:error, error} ->
            {:reply, {:error, error}, state}
        end
      end

      @doc """
      Appends a list of events to a stream.
      """
      def handle_call(
            %AppendCommand{
              stream_name: stream_name,
              events: events,
              expected_version: expected_version
            },
            _from,
            state
          ) do
        case append(stream_name, events, state, expected_version) do
          {:ok, version, events, new_state} ->
            {:reply, {:ok, version, events}, new_state}

          {:ok, version, events} ->
            {:reply, {:ok, version, events}, state}

          {:error, error, new_state} ->
            {:reply, {:error, error}, new_state}

          {:error, error} ->
            {:reply, {:error, error}, state}
        end
      end

      def handle_call({:delete_events, stream_name, version}, _from, state) do
        case delete(stream_name, version, state) do
          :ok ->
            {:reply, :ok, state}

          {:ok, new_state} ->
            {:reply, :ok, new_state}

          {:error, error, new_state} ->
            {:reply, {:error, error}, new_state}

          {:error, error} ->
            {:reply, {:error, error}, state}
        end
      end
    end
  end
end
