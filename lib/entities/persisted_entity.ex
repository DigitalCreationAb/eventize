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

      def handle_continue(
            :initialize_events,
            %{id: id, event_bus: event_bus, state: state, behavior: behavior} = entity_state
          ) do
        {:ok, version, events} = event_bus.load_events(get_stream_name(id))

        {new_state, new_behavior} = run_event_handlers(events, state, behavior)

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
        {:ok, version, stored_events} =
          event_bus.append_events(
            get_stream_name(id),
            events |> Enum.map(fn event -> {event, get_event_meta_data(event)} end),
            version
          )

        {new_state, new_behavior} = run_event_handlers(stored_events, state, behavior)

        {%{entity_state | state: new_state, behavior: new_behavior, version: version}, stored_events}
      end

      defp run_event_applier(
             %Reactive.Persistence.EventBus.EventData{
               payload: payload,
               meta_data: meta_data,
               sequence_number: sequence_number
             },
             state
           ) do
        apply_event(payload, state, Map.put(meta_data, :sequence_number, sequence_number))
      end

      defp cleanup(
             %Reactive.Persistence.EventBus.EventData{
               payload: payload,
               meta_data: meta_data,
               sequence_number: sequence_number
             },
             entity_state
           ) do
        cleanup(payload, entity_state, Map.put(meta_data, :sequence_number, sequence_number))
      end

      defp run_cleanup({:delete_events, version}, current_return, %{id: id, event_bus: event_bus}) do
        :ok = event_bus.delete(get_stream_name(id), version)

        current_return
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

      defp apply_event(event, state, _meta_data), do: apply_event(event, state)

      defp cleanup(event, state, _meta_data), do: cleanup(event, state)
    end
  end
end
