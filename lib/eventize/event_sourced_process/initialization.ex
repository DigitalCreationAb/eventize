defmodule Eventize.EventSourcedProcess.Initialization do
  @moduledoc """
  This module will handle initialization for a
  `Eventize.EventSourcedProcess`
  """

  @doc """
  A callback used when the process is starting up. This should
  return either a two item tuple where the first item is the
  initial behavior and the second is the initial state, a single
  item that is either the initial state, the initial state or nil.
  """
  @callback start(id :: String.t()) :: {atom(), map()} | atom() | map() | nil

  @doc """
  This callback can optionally be implimented to return
  the stream name that should be used when the events
  of this process is stored in the configured
  `Eventize.Persistence.EventStore`. The default
  implimentation will use the last part (seperate on ".")
  of the module name lowercased and add the id of the
  process.
  """
  @callback get_stream_name(String.t()) :: String.t()

  @optional_callbacks start: 1,
                      get_stream_name: 1

  defmacro __using__(_) do
    quote location: :keep, generated: true do
      alias Eventize.Persistence.EventStore.SnapshotData
      alias Eventize.EventSourcedProcessState

      @behaviour Eventize.EventSourcedProcess.Initialization

      @doc false
      @impl GenServer
      def init(%{id: id, event_bus: event_bus}) do
        event_bus = Eventize.Persistence.EventStore.parse_event_bus(event_bus)

        {initial_behavior, initial_state} =
          case start(id) do
            nil ->
              {__MODULE__, nil}

            {behavior, initial_state} when is_atom(behavior) ->
              {behavior, initial_state}

            behavior when is_atom(behavior) ->
              {behavior, nil}

            initial_state ->
              {__MODULE__, initial_state}
          end

        process_state = %EventSourcedProcessState{
          state: initial_state,
          behavior: initial_behavior,
          id: id,
          event_bus: event_bus,
          version: 0,
          stream_name: get_stream_name(id),
          process: __MODULE__
        }

        {:ok, process_state, {:continue, :initialize_events}}
      end

      @impl GenServer
      def init(%{id: id} = data), do: init(Map.put(data, :event_bus, nil))

      @doc false
      @impl GenServer
      def handle_continue(
            :initialize_events,
            %EventSourcedProcessState{
              event_bus: event_bus,
              state: state,
              behavior: behavior,
              stream_name: stream_name
            } = process_state
          ) do
        {new_state, new_behavior, version} =
          case event_bus.load_snapshot.(stream_name, :max) do
            {:ok, nil} ->
              {:ok, version, events} = event_bus.load_events.(stream_name, :start, :all)

              {new_state, new_behavior} = run_event_handlers(events, state, behavior)

              {new_state, new_behavior, version}

            {:ok,
             %SnapshotData{payload: _payload, meta_data: _meta_data, version: version} = snapshot} ->
              {new_state, new_behavior} = run_snapshot_handler(snapshot, process_state)

              {:ok, version, events} = event_bus.load_events.(stream_name, version, :all)

              {new_state, new_behavior} = run_event_handlers(events, new_state, new_behavior)

              {new_state, new_behavior, version}
          end

        {:noreply,
         %EventSourcedProcessState{
           process_state
           | behavior: new_behavior,
             state: new_state,
             version: version
         }}
      end

      def start(_id), do: %{}

      def get_stream_name(id) do
        [module_name | _] =
          Atom.to_string(__MODULE__)
          |> String.split(".")
          |> Enum.take(-1)

        "#{String.downcase(module_name)}-#{id}"
      end

      defoverridable start: 1,
                     get_stream_name: 1
    end
  end
end
