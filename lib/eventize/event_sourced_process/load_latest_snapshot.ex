defmodule Eventize.EventSourcedProcess.LoadLatestSnapshot do
  @moduledoc false

  defmodule SnapshotContext do
    @moduledoc false

    @type t :: %__MODULE__{
            state: term(),
            meta_data: map(),
            version: non_neg_integer()
          }

    defstruct [:state, :meta_data, :version]
  end

  alias Eventize.Persistence.EventStore.SnapshotData
  alias Eventize.EventSourcedProcessState
  alias Eventize.EventSourcedProcess.InitPipeline.ExecutionContext

  @behaviour Eventize.EventSourcedProcess.InitPipeline.PipelineStep

  @callback apply_snapshot(term(), term()) :: {term(), atom()} | term()

  @callback apply_snapshot(term(), term(), map()) :: {term(), atom()} | term()

  @callback get_snapshot_meta_data(term()) :: map()

  @optional_callbacks apply_snapshot: 2,
                      apply_snapshot: 3,
                      get_snapshot_meta_data: 1

  def init(
        %ExecutionContext{
          state:
            %EventSourcedProcessState{
              stream_name: stream_name,
              event_bus: event_bus
            } = process_state
        } = context,
        next
      ) do
    case event_bus.load_snapshot.(stream_name, :max) do
      {:ok, %SnapshotData{version: version} = snapshot} ->
        {new_state, new_behavior} = run_snapshot_handler(snapshot, process_state)

        next.(%ExecutionContext{
          context
          | state: %EventSourcedProcessState{
              process_state
              | state: new_state,
                behavior: new_behavior,
                start_from: version
            }
        })

      {:ok, nil} ->
        next.(context)

      err ->
        %ExecutionContext{context | build_response: fn s -> {:stop, err, s} end}
    end
  end

  def run_snapshot_handler(
        %SnapshotData{payload: payload, meta_data: meta_data, version: version},
        %EventSourcedProcessState{state: state, behavior: behavior, process: process}
      ) do
    response =
      process.apply_snapshot(payload, %SnapshotContext{
        state: state,
        meta_data: meta_data,
        version: version
      })

    case response do
      {new_state, nil} -> {new_state, process}
      {new_state, new_behavior} -> {new_state, new_behavior}
      new_state -> {new_state, behavior}
    end
  end
end
