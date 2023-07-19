defmodule Eventize.EventSourcedProcess.InitDefaultState do
  @moduledoc false

  @behaviour Eventize.EventSourcedProcess.InitPipeline.PipelineStep

  alias Eventize.EventSourcedProcess.InitPipeline.ExecutionContext

  @doc """
  Initializes the default state for the process.
  """
  @spec init(
          ExecutionContext.t(),
          Eventize.EventSourcedProcess.InitPipeline.execution_pipeline()
        ) :: ExecutionContext.t()
  def init(
        %Eventize.EventSourcedProcess.InitPipeline.ExecutionContext{
          state: state,
          input: input,
          process: process
        } = context,
        next
      ) do
    {id, event_bus} =
      case input do
        list when is_list(list) ->
          {Keyword.get(list, :id, UUID.uuid4()), Keyword.get(list, :event_bus, nil)}

        map when is_map(map) ->
          {Map.get(map, :id, UUID.uuid4()), Map.get(map, :event_bus, nil)}

        _ ->
          {UUID.uuid4(), nil}
      end

    next.(%Eventize.EventSourcedProcess.InitPipeline.ExecutionContext{
      context
      | state: %Eventize.EventSourcedProcessState{
          state
          | id: id,
            event_bus: Eventize.Persistence.EventStore.parse_event_bus(event_bus),
            process: process,
            behavior: process,
            version: :empty,
            stream_name: process.get_stream_name(id)
        }
    })
  end
end
