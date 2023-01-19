defmodule Eventize.EventSourcedProcess.ExecuteHandler do
  @moduledoc """
  A module that takes care of execution of a message.
  """

  alias Eventize.EventSourcedProcess.ExecutionPipeline.ExecutionContext

  @behaviour Eventize.EventSourcedProcess.ExecutionPipeline.PipelineStep

  @callback execute_call(term(), pid(), map()) :: {list(), term()} | list() | term()

  @callback execute_cast(term(), map()) :: list() | nil

  @optional_callbacks execute_call: 3,
                      execute_cast: 2

  def execute(
        %ExecutionContext{
          input: input,
          type: :call,
          from: from,
          state: %Eventize.EventSourcedProcessState{behavior: behavior, id: id, state: state},
          step_data: %{message_id: message_id, correlation_id: correlation_id} = step_data
        } = context,
        next
      ) do
    {events, response} =
      case behavior.execute_call(input, from, %{
             id: id,
             state: state,
             causation_id: message_id,
             correlation_id: correlation_id
           }) do
        {events, response} when is_list(events) ->
          {events, response}

        events when is_list(events) ->
          {events, :ok}

        response ->
          {[], response}
      end

    next.(%ExecutionContext{
      context
      | build_response: fn s -> {:reply, response, s} end,
        step_data: Map.put(step_data, :events, events)
    })
  end

  def execute(
        %ExecutionContext{
          input: input,
          type: :cast,
          state: %Eventize.EventSourcedProcessState{behavior: behavior, id: id, state: state},
          step_data: %{message_id: message_id, correlation_id: correlation_id} = step_data
        } = context,
        next
      ) do
    events =
      case behavior.execute_cast(input, %{
             id: id,
             state: state,
             causation_id: message_id,
             correlation_id: correlation_id
           }) do
        events when is_list(events) ->
          events

        _ ->
          []
      end

    next.(%ExecutionContext{
      context
      | build_response: fn s -> {:noreply, s} end,
        step_data: Map.put(step_data, :events, events)
    })
  end
end
