defmodule Eventize.EventSourcedProcess.EventApplyer do
  @moduledoc """
  A module that impliments event apply
  functionality for a `Eventize.EventSourcedProcess`.
  """

  @callback apply_event(term(), term(), map()) :: {term(), atom()} | term()

  @callback apply_event(term(), term()) :: {term(), atom()} | term()

  @callback apply_snapshot(term(), term()) :: {term(), atom()} | term()

  @callback apply_snapshot(term(), term(), map()) :: {term(), atom()} | term()

  @callback get_event_meta_data(term()) :: map()

  @callback get_snapshot_meta_data(term()) :: map()

  @optional_callbacks apply_event: 3,
                      apply_event: 2,
                      apply_snapshot: 2,
                      apply_snapshot: 3,
                      get_event_meta_data: 1,
                      get_snapshot_meta_data: 1

  defmacro __using__(_) do
    quote location: :keep, generated: true do
      alias Eventize.Persistence.EventStore.EventData
      alias Eventize.Persistence.EventStore.SnapshotData
      alias Eventize.EventSourcedProcessState

      @behaviour Eventize.EventSourcedProcess.EventApplyer

      @before_compile Eventize.EventSourcedProcess.EventApplyer

      def apply_events(
             events,
             %EventSourcedProcessState{
               id: id,
               state: state,
               behavior: behavior,
               event_bus: event_bus,
               version: version,
               stream_name: stream_name
             } = process_state,
             %{} = additional_meta_data
           )
           when is_list(events) do
        {:ok, version, stored_events} =
          event_bus.append_events.(
            stream_name,
            events
            |> Enum.map(fn event ->
              {event, Map.merge(additional_meta_data, get_event_meta_data(event))}
            end),
            version
          )

        {new_state, new_behavior} = run_event_handlers(stored_events, state, behavior)

        {%EventSourcedProcessState{
           process_state
           | state: new_state,
             behavior: new_behavior,
             version: version
         }, stored_events}
      end

      def run_event_handlers(events, state, current_behavior) when is_list(events) do
        Enum.reduce(events, {state, current_behavior}, fn %EventData{
                                                            payload: payload,
                                                            meta_data: meta_data,
                                                            sequence_number: sequence_number
                                                          },
                                                          {state, behavior} ->
          case apply_event(payload, state, Map.put(meta_data, :sequence_number, sequence_number)) do
            {new_state, nil} -> {new_state, __MODULE__}
            {new_state, new_behavior} -> {new_state, new_behavior}
            new_state -> {new_state, behavior}
          end
        end)
      end

      def run_snapshot_handler(
             %SnapshotData{payload: payload, meta_data: meta_data, version: version},
             %EventSourcedProcessState{state: state, behavior: behavior}
           ) do
        response = apply_snapshot(payload, state, Map.put(meta_data, :version, version))

        case response do
          {new_state, nil} -> {new_state, __MODULE__}
          {new_state, new_behavior} -> {new_state, new_behavior}
          new_state -> {new_state, behavior}
        end
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def apply_event(_event, state), do: state

      def apply_event(event, state, _meta_data), do: apply_event(event, state)

      def apply_snapshot(_snapshot, state), do: state

      def apply_snapshot(snapshot, state, _meta_data), do: apply_snapshot(snapshot, state)

      def get_event_meta_data(_event), do: %{}

      def get_snapshot_meta_data(_snapshot), do: %{}

      defoverridable apply_event: 2,
                     apply_event: 3,
                     apply_snapshot: 2,
                     apply_snapshot: 3,
                     get_event_meta_data: 1,
                     get_snapshot_meta_data: 1
    end
  end
end
