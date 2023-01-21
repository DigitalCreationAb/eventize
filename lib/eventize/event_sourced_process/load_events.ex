defmodule Eventize.EventSourcedProcess.LoadEvents do
  @moduledoc false

  alias Eventize.EventSourcedProcessState
  alias Eventize.EventSourcedProcess.InitPipeline.ExecutionContext

  @behaviour Eventize.EventSourcedProcess.InitPipeline.PipelineStep

  alias Eventize.EventSourcedProcess.InitPipeline.ExecutionContext

  @spec init(
          ExecutionContext.t(),
          Eventize.EventSourcedProcess.InitPipeline.execution_pipeline()
        ) :: ExecutionContext.t()
  def init(
        %ExecutionContext{
          state:
            %EventSourcedProcessState{
              stream_name: stream_name,
              event_bus: event_bus,
              start_from: start_from
            } = process_state,
          step_data: step_data
        } = context,
        next
      ) do
    case event_bus.load_events.(stream_name, start_from, :all) do
      {:ok, events, process_version} ->
        next.(%ExecutionContext{
          context
          | state: %EventSourcedProcessState{process_state | version: process_version},
            step_data: Map.put(step_data, :events, events)
        })

      err ->
        %ExecutionContext{context | build_response: fn s -> {:stop, err, s} end}
    end
  end
end
