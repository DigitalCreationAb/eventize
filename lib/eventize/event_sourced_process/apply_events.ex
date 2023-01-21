defmodule Eventize.EventSourcedProcess.ApplyEvents do
  @moduledoc """
  A pipeline step that is used to apply events to a
  `Eventize.EventSourcedProcess` both at startup
  and after a message has been executed.
  """

  defmodule EventContext do
    @moduledoc """
    A context containing useful data to apply a event
    to a `Eventize.EventSourcedProcess`.
    """

    @type t :: %__MODULE__{
            state: term(),
            meta_data: map(),
            sequence_number: non_neg_integer()
          }

    @enforce_keys [:state, :meta_data, :sequence_number]

    defstruct [:state, :meta_data, :sequence_number]
  end

  alias Eventize.EventSourcedProcess.ExecutionPipeline.ExecutionContext
  alias Eventize.EventSourcedProcess.InitPipeline.ExecutionContext, as: InitExecutionContext
  alias Eventize.Persistence.EventStore.EventData

  @behaviour Eventize.EventSourcedProcess.ExecutionPipeline.PipelineStep
  @behaviour Eventize.EventSourcedProcess.InitPipeline.PipelineStep

  @spec init(
          InitExecutionContext.t(),
          Eventize.EventSourcedProcess.InitPipeline.execution_pipeline()
        ) :: InitExecutionContext.t()
  def init(
        %InitExecutionContext{
          state:
            %Eventize.EventSourcedProcessState{
              process: process,
              state: state,
              behavior: current_behavior
            } = process_state,
          step_data: %{
            events: events
          }
        } = context,
        next
      ) do
    {new_state, new_behavior} = run(events, state, current_behavior, process)

    next.(%InitExecutionContext{
      context
      | state: %Eventize.EventSourcedProcessState{
          process_state
          | state: new_state,
            behavior: new_behavior
        }
    })
  end

  @spec execute(
          ExecutionContext.t(),
          Eventize.EventSourcedProcess.ExecutionPipeline.execution_pipeline()
        ) :: ExecutionContext.t()
  def execute(
        %ExecutionContext{
          state:
            %Eventize.EventSourcedProcessState{
              process: process,
              state: state,
              behavior: current_behavior
            } = process_state,
          step_data: %{
            events: events
          }
        } = context,
        next
      ) do
    {new_state, new_behavior} = run(events, state, current_behavior, process)

    next.(%ExecutionContext{
      context
      | state: %Eventize.EventSourcedProcessState{
          process_state
          | state: new_state,
            behavior: new_behavior
        }
    })
  end

  defp run(events, state, current_behavior, process) do
    Enum.reduce(events, {state, current_behavior}, fn %EventData{
                                                        payload: payload,
                                                        meta_data: meta_data,
                                                        sequence_number: sequence_number
                                                      },
                                                      {state, behavior} ->
      case process.apply_event(
             payload,
             %EventContext{
               state: state,
               meta_data: meta_data,
               sequence_number: sequence_number
             }
           ) do
        {new_state, nil} -> {new_state, process}
        {new_state, new_behavior} -> {new_state, new_behavior}
        new_state -> {new_state, behavior}
      end
    end)
  end
end
