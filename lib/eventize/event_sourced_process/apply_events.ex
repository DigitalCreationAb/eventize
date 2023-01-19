defmodule Eventize.EventSourcedProcess.ApplyEvents do
  @moduledoc false

  defmodule EventContext do
    @moduledoc false

    @type t :: %__MODULE__{
            state: term(),
            meta_data: map(),
            sequence_number: non_neg_integer()
          }

    defstruct [:state, :meta_data, :sequence_number]
  end

  alias Eventize.EventSourcedProcess.ExecutionPipeline.ExecutionContext
  alias Eventize.Persistence.EventStore.EventData

  @behaviour Eventize.EventSourcedProcess.ExecutionPipeline.PipelineStep
  @behaviour Eventize.EventSourcedProcess.InitPipeline.PipelineStep

  @callback apply_event(term(), term(), map()) :: {term(), atom()} | term()

  @callback apply_event(term(), term()) :: {term(), atom()} | term()

  @callback get_event_meta_data(term()) :: map()

  @optional_callbacks apply_event: 3,
                      apply_event: 2,
                      get_event_meta_data: 1

  def init(
        %Eventize.EventSourcedProcess.InitPipeline.ExecutionContext{
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

    next.(%Eventize.EventSourcedProcess.InitPipeline.ExecutionContext{
      context
      | state: %Eventize.EventSourcedProcessState{
          process_state
          | state: new_state,
            behavior: new_behavior
        }
    })
  end

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
