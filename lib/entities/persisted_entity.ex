defmodule Reactive.Entities.PersistedEntity do
  @moduledoc """
  PersistedEntity is a `Reactive.Entities.Entity` that will
  use event sourcing to store its applied events.
  """

  defmacro __using__(_) do
    quote location: :keep do
      use Reactive.Entities.Entity
      alias Reactive.Entities.Entity
      alias Reactive.Persistence.EventStore

      @doc """
      Initializes the PersistedEntity with the initial state.
      Then it uses `:continue` to read the events from the
      `Reactive.Persistence.EventStore` in the background.
      """
      def init(%{:id => id, :event_bus => event_bus}) do
        entity_state = Map.put(initialize_state(id), :event_bus, event_bus)

        {:ok, entity_state, {:continue, :initialize_events}}
      end

      @doc """
      Uses the `Reactive.Persistence.EventStore` to load all
      events for the current entity and runs all event handler
      to updated the process state.
      """
      def handle_continue(:initialize_events, entity_state) do
        events = load_events(entity_state)

        {new_state, new_behavior, _} =
          run_event_handlers(events, entity_state.state, entity_state.behavior)

        {:noreply, %{entity_state | behavior: new_behavior, state: new_state}}
      end

      defp load_events(%{:id => id, :event_bus => event_bus}) do
        event_bus.load_events(get_stream_name(id))
      end

      defp apply_events(events, %{
             :id => id,
             :state => state,
             :behavior => behavior,
             :event_bus => event_bus
           })
           when is_list(events) do
        event_bus.append_events(get_stream_name(id), events)

        run_event_handlers(events, state, behavior)
      end

      defp get_stream_name(id) do
        [module_name | _] =
          Atom.to_string(__MODULE__)
          |> String.split(".")
          |> Enum.take(-1)

        "#{String.downcase(module_name)}-#{id}"
      end

      defoverridable get_stream_name: 1
    end
  end
end
