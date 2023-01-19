defmodule Eventize.EventSourcedProcess do
  @moduledoc """
  EventSourcedProcess is a optininated `GenServer` that will
  use event sourcing to store its state as a sequence of events.

  Instead of using the normal `c:GenServer.handle_call/3` and `c:GenServer.handle_cast/2`
  callbacks you can now use `c:Eventize.EventSourcedProcess.ExecuteHandler.execute_call/3`
  and `c:Eventize.EventSourcedProcess.ExecuteHandler.execute_cast/2`.
  These function very similar, but instead of modifying the state
  you can return a list of events that should be applied. These
  events will be stored using the configured event bus and then
  applied to the process using the `c:Eventize.EventSourcedProcess.ApplyEvents.apply_event/2`
  or `c:Eventize.EventSourcedProcess.ApplyEvents.apply_event/3` callback.
  All stored events will also be read on startup and the
  `c:Eventize.EventSourcedProcess.ApplyEvents.apply_event/3`
  functions will be called then as well to make sure that the state
  is up to date.
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

  defmodule MessageMetaData do
    @moduledoc false

    @type t :: %__MODULE__{
            message_id: String.t(),
            correlation_id: String.t()
          }

    defstruct [:message_id, :correlation_id]
  end

  @optional_callbacks start: 1,
                      get_stream_name: 1

  defmacro __using__(_) do
    quote location: :keep, generated: true do
      use GenServer

      alias Eventize.EventSourcedProcess.ExecutionPipeline.ExecutionContext
      alias Eventize.Persistence.EventStore.SnapshotData
      alias Eventize.Persistence.EventStore.EventData
      alias Eventize.EventSourcedProcessState
      alias Eventize.EventSourcedProcess.RunCleanups.CleanupContext
      alias Eventize.EventSourcedProcess.ApplyEvents.EventContext
      alias Eventize.EventSourcedProcess.LoadLatestSnapshot.SnapshotContext

      @behaviour Eventize.EventSourcedProcess
      @behaviour Eventize.EventSourcedProcess.ExecuteHandler
      @behaviour Eventize.EventSourcedProcess.ApplyEvents
      @behaviour Eventize.EventSourcedProcess.RunCleanups
      @behaviour Eventize.EventSourcedProcess.LoadLatestSnapshot

      @before_compile Eventize.EventSourcedProcess

      @default_execution_pipeline [
        Eventize.EventSourcedProcess.RunCleanups,
        Eventize.EventSourcedProcess.ExecuteHandler,
        Eventize.EventSourcedProcess.EnrichEventsWithMetaData,
        Eventize.EventSourcedProcess.StoreEvents,
        Eventize.EventSourcedProcess.ApplyEvents
      ]

      @doc false
      @impl GenServer
      def handle_cast(
            {message, %MessageMetaData{} = message_meta_data},
            %EventSourcedProcessState{
              id: id,
              state: state,
              behavior: behavior
            } = process_state
          ) do
        message_id = Map.get(message_meta_data, :message_id, UUID.uuid4())
        correlation_id = Map.get(message_meta_data, :correlation_id, UUID.uuid4())

        execution_pipeline = get_execution_pipeline(message)

        %ExecutionContext{build_response: build_response, state: state} =
          execution_pipeline.(%ExecutionContext{
            input: message,
            build_response: fn s -> {:noreply, s} end,
            state: process_state,
            step_data: %{message_id: message_id, correlation_id: correlation_id},
            type: :cast,
            from: nil
          })

        build_response.(state)
      end

      @impl GenServer
      def handle_cast(message, process_state),
        do:
          handle_cast(
            {message, %MessageMetaData{}},
            process_state
          )

      @doc false
      @impl GenServer
      def handle_call(
            {message, %MessageMetaData{} = message_meta_data},
            from,
            %EventSourcedProcessState{
              id: id,
              state: state,
              behavior: behavior
            } = process_state
          ) do
        message_id = Map.get(message_meta_data, :message_id, UUID.uuid4())
        correlation_id = Map.get(message_meta_data, :correlation_id, UUID.uuid4())

        execution_pipeline = get_execution_pipeline(message)

        %ExecutionContext{build_response: build_response, state: state} =
          execution_pipeline.(%ExecutionContext{
            input: message,
            build_response: fn s -> {:reply, :ok, s} end,
            state: process_state,
            step_data: %{message_id: message_id, correlation_id: correlation_id},
            type: :call,
            from: from
          })

        build_response.(state)
      end

      @impl GenServer
      def handle_call(message, from, process_state),
        do:
          handle_call(
            {message, %MessageMetaData{}},
            from,
            process_state
          )

      @doc false
      @impl GenServer
      def init(args) do
        {:ok,
         %Eventize.EventSourcedProcess.InitPipeline.ExecutionContext{
           input: args,
           state: %EventSourcedProcessState{},
           process: __MODULE__,
           build_response: fn s -> {:noreply, s} end
         }, {:continue, :start}}
      end

      @doc false
      @impl GenServer
      def handle_continue(
            :start,
            %Eventize.EventSourcedProcess.InitPipeline.ExecutionContext{} = context
          ) do
        pipeline =
          Eventize.EventSourcedProcess.InitPipeline.build_pipeline([
            Eventize.EventSourcedProcess.InitDefaultState,
            Eventize.EventSourcedProcess.ExecuteStartup,
            Eventize.EventSourcedProcess.LoadLatestSnapshot,
            Eventize.EventSourcedProcess.LoadEvents,
            Eventize.EventSourcedProcess.ApplyEvents
          ])

        new_context = pipeline.(context)

        new_context.build_response.(new_context.state)
      end

      @doc false
      @impl GenServer
      def handle_info(:timeout, state) do
        {:stop, :normal, state}
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote generated: true do
      def start(_id), do: %{}

      def get_stream_name(id) do
        [module_name | _] =
          Atom.to_string(__MODULE__)
          |> String.split(".")
          |> Enum.take(-1)

        "#{String.downcase(module_name)}-#{id}"
      end

      def get_execution_pipeline(_message) do
        Eventize.EventSourcedProcess.ExecutionPipeline.build_pipeline(@default_execution_pipeline)
      end

      def cleanup(_event, _context), do: []

      def apply_event(_event, %Eventize.EventSourcedProcess.ApplyEvents.EventContext{state: state}),
          do: state

      def apply_snapshot(
            _snapshot,
            %Eventize.EventSourcedProcess.LoadLatestSnapshot.SnapshotContext{state: state}
          ),
          do: state

      def get_event_meta_data(_event), do: %{}

      def get_snapshot_meta_data(_snapshot), do: %{}

      defoverridable start: 1,
                     cleanup: 2,
                     apply_event: 2,
                     apply_snapshot: 2,
                     get_event_meta_data: 1,
                     get_snapshot_meta_data: 1,
                     get_execution_pipeline: 1
    end
  end
end
