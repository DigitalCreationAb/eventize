defmodule PersistedEntity do
  defmacro __using__(_) do
    quote location: :keep do
      use Reactive.Entities.Entity
      alias Reactive.Entities.Entity
      alias Reactive.Persistence.EventStore

      @behaviour Reactive.Entities.PersistedEntity

      def init(id) do
        entity_state = initialize_state(id)
        
        events = load_events(entity_state)

        {new_state, new_behavior} = run_event_handlers(events, entity_state.state, entity_state.behavior)

        {:ok, %EntityState{id: id, behavior: new_behavior, state: new_state}}
      end
      
      defp load_events(%EntityState{id => id}) do
        EventStore.load_events(get_stream_name(id))
      end

      defp apply_events(events, %EntityState{:id => id, :state => state, :behavior => behavior}) when is_list(events) do
        EventStore.append_events(get_stream_name(id), events)
        
        run_event_handlers(events, state, behavior)
      end
      
      defp get_stream_name(id) do
        id
      end
      
      defoverridable [get_stream_name: 1]
    end
  end
end