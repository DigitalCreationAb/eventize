defmodule Eventize.EventSourcedProcess.HandleConflictingEvents do
  @moduledoc false

  alias Eventize.EventSourcedProcess.ExecutionPipeline.ExecutionContext

  @behaviour Eventize.EventSourcedProcess.ExecutionPipeline.PipelineStep

  @spec execute(
          ExecutionContext.t(),
          Eventize.EventSourcedProcess.ExecutionPipeline.execution_pipeline()
        ) :: ExecutionContext.t()
  def execute(
        %ExecutionContext{} = context,
        next
      ) do
    context = next.(context)

    case context do
      %ExecutionContext{
        step_data: %{
          store_events_response: {:error, {:expected_version_missmatch, _}}
        }
      } ->


      c -> c
    end

    response =
      case events do
        [] ->
          {:ok, [], version}

        events ->
          event_bus.append_events.(
            stream_name,
            events,
            version
          )
      end

    case response do
      {:ok, events, sequence_number} ->
        next.(%ExecutionContext{
          context
          | step_data:
              step_data
              |> Map.put(:events, events)
              |> Map.put(:store_events_response, response),
            state: %Eventize.EventSourcedProcessState{process_state | version: sequence_number}
        })

      err ->
        %ExecutionContext{
          context
          | build_response: fn s ->
              case type do
                :call ->
                  {:reply, err, s}

                :cast ->
                  {:noreply, s}
              end
            end,
            step_data:
              step_data
              |> Map.put(:store_events_response, response)
        }
    end
  end
end
