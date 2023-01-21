defmodule Eventize.EventSourcedProcess.EnrichEventsWithMetaData do
  @moduledoc false

  alias Eventize.EventSourcedProcess.ExecutionPipeline.ExecutionContext

  @behaviour Eventize.EventSourcedProcess.ExecutionPipeline.PipelineStep

  @spec execute(
          ExecutionContext.t(),
          Eventize.EventSourcedProcess.ExecutionPipeline.execution_pipeline()
        ) :: ExecutionContext.t()
  def execute(
        %ExecutionContext{
          state: %Eventize.EventSourcedProcessState{process: process},
          step_data:
            %{message_id: message_id, correlation_id: correlation_id, events: events} = step_data
        } = context,
        next
      ) do
    base_meta_data = %{
      causation_id: message_id,
      correlation_id: correlation_id
    }

    new_events =
      events
      |> Enum.map(fn event ->
        {event, Map.merge(base_meta_data, process.get_event_meta_data(event))}
      end)

    next.(%ExecutionContext{context | step_data: %{step_data | events: new_events}})
  end
end
