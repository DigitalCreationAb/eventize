defmodule Eventize.EventSourcedProcess.ExecuteStartup do
  @moduledoc false

  @behaviour Eventize.EventSourcedProcess.InitPipeline.PipelineStep

  alias Eventize.EventSourcedProcess.InitPipeline.ExecutionContext

  @doc """
  Execute the `c:Eventize.EventSourcedProcess.start/1` callback when
  starting up the process.
  """
  @spec init(
          ExecutionContext.t(),
          Eventize.EventSourcedProcess.InitPipeline.execution_pipeline()
        ) :: ExecutionContext.t()
  def init(
        %ExecutionContext{
          state: %Eventize.EventSourcedProcessState{} = state,
          process: process,
          input: input
        } = context,
        next
      ) do
    {initial_behavior, initial_state} =
      case process.start(input) do
        nil ->
          {process, nil}

        {behavior, initial_state} when is_atom(behavior) ->
          {behavior, initial_state}

        behavior when is_atom(behavior) ->
          {behavior, nil}

        initial_state ->
          {process, initial_state}
      end

    next.(%ExecutionContext{
      context
      | state: %Eventize.EventSourcedProcessState{
          state
          | state: initial_state,
            behavior: initial_behavior
        }
    })
  end
end
