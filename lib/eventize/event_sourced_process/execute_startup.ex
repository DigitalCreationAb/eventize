defmodule Eventize.EventSourcedProcess.ExecuteStartup do
  @moduledoc false

  @behaviour Eventize.EventSourcedProcess.InitPipeline.PipelineStep

  def init(
        %Eventize.EventSourcedProcess.InitPipeline.ExecutionContext{
          state: %Eventize.EventSourcedProcessState{id: id} = state,
          process: process
        } = context,
        next
      ) do
    {initial_behavior, initial_state} =
      case process.start(id) do
        nil ->
          {process, nil}

        {behavior, initial_state} when is_atom(behavior) ->
          {behavior, initial_state}

        behavior when is_atom(behavior) ->
          {behavior, nil}

        initial_state ->
          {process, initial_state}
      end

    next.(%Eventize.EventSourcedProcess.InitPipeline.ExecutionContext{
      context
      | state: %Eventize.EventSourcedProcessState{
          state
          | state: initial_state,
            behavior: initial_behavior
        }
    })
  end
end
