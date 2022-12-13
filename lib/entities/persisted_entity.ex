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

      @before_compile Reactive.Entities.PersistedEntity

      @doc """
      Initializes the PersistedEntity with the initial state.
      Then it uses `:continue` to read the events from the
      `Reactive.Persistence.EventStore` in the background.
      """
      def init(%{id: id, event_bus: event_bus}) do
        entity_state =
          initialize_state(id) |> Map.put(:event_bus, event_bus) |> Map.put(:version, 0)

        {:ok, entity_state, {:continue, :initialize_events}}
      end

      @doc """
      Uses the `Reactive.Persistence.EventStore` to load all
      events for the current entity and runs all event handler
      to updated the process state.
      """
      def handle_continue(
            :initialize_events,
            %{id: id, event_bus: event_bus, state: state, behavior: behavior} = entity_state
          ) do
        {:ok, version, events} = event_bus.load_events(get_stream_name(id))

        {new_state, new_behavior, _} =
          run_event_handlers(events |> Enum.map(fn event -> event.payload end), state, behavior)

        {:noreply, %{entity_state | behavior: new_behavior, state: new_state, version: version}}
      end

      defp apply_events(
             events,
             %{
               id: id,
               state: state,
               behavior: behavior,
               event_bus: event_bus,
               version: version
             } = entity_state
           )
           when is_list(events) do
        {:ok, version} =
          event_bus.append_events(
            get_stream_name(id),
            events |> Enum.map(fn event -> {event, get_event_meta_data(event)} end),
            version
          )

        {new_state, new_behavior, life_span} = run_event_handlers(events, state, behavior)

        {%{entity_state | state: new_state, behavior: new_behavior, version: version}, life_span}
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

  defmacro __before_compile__(_env) do
    quote do
      defp get_event_meta_data(_event), do: %{}

      defoverridable get_event_meta_data: 1
    end
  end
end
