defmodule Reactive.Entities.PersistedEntity do
  @moduledoc """
  PersistedEntity is a `Reactive.Entities.Entity` that will
  use event sourcing to store its applied events.
  """

  @type event_bus_interop :: %{
          load_events:
            (String.t(), :start | non_neg_integer(), :all | non_neg_integer() ->
               EventStore.events_response()),
          append_events:
            (String.t(), list({term(), map()}), non_neg_integer() -> EventStore.events_response()),
          delete_events: (String.t(), non_neg_integer() -> EventStore.events_response()),
          load_snapshot: (String.t(), :max | non_neg_integer() -> EventStore.snapshot_response()),
          append_snapshot:
            (String.t(), {term(), map()}, non_neg_integer(), :any | non_neg_integer() ->
               EventStore.snapshot_response()),
          delete_snapshots: (String.t(), non_neg_integer() -> EventStore.delete_response())
        }

  defmacro __using__(_) do
    quote location: :keep do
      use Reactive.Entities.Entity
      alias Reactive.Entities.Entity
      alias Reactive.Persistence.EventStore
      alias Reactive.Persistence.EventStore.EventData
      alias Reactive.Persistence.EventStore.SnapshotData

      @before_compile Reactive.Entities.PersistedEntity

      defguardp is_event_bus_interop(event_bus)
                when is_map(event_bus) and is_map_key(event_bus, :load_events) and
                       is_map_key(event_bus, :append_events) and
                       is_map_key(event_bus, :delete_events) and
                       is_function(event_bus.load_events, 3) and
                       is_function(event_bus.append_events, 3) and
                       is_function(event_bus.delete_events, 2) and
                       is_function(event_bus.load_snapshot, 2) and
                       is_function(event_bus.append_snapshot, 4) and
                       is_function(event_bus.delete_snapshots, 2)

      @doc """
      Initializes the PersistedEntity with the initial state.
      Then it uses `:continue` to read the events from the
      `Reactive.Persistence.EventStore` in the background.
      """
      def init(%{id: id, event_bus: event_bus}) do
        event_bus =
          case event_bus do
            eb when is_event_bus_interop(eb) ->
              eb

            pid ->
              %{
                load_events: fn stream_name, start, max_count ->
                  GenServer.call(
                    pid,
                    {:load_events,
                     %{
                       stream_name: stream_name,
                       start: start,
                       max_count: max_count
                     }}
                  )
                end,
                append_events: fn stream_name, events, expected_version ->
                  GenServer.call(
                    pid,
                    {:append_events,
                     %{
                       stream_name: stream_name,
                       events: events,
                       expected_version: expected_version
                     }}
                  )
                end,
                delete_events: fn stream_name, version ->
                  GenServer.call(
                    pid,
                    {:delete_events, %{stream_name: stream_name, version: version}}
                  )
                end,
                load_snapshot: fn stream_name, max_version ->
                  GenServer.call(
                    pid,
                    {:load_snapshot, %{stream_name: stream_name, max_version: max_version}}
                  )
                end,
                append_snapshot: fn stream_name, snapshot, version, expected_version ->
                  GenServer.call(
                    pid,
                    {:append_snapshot,
                     %{
                       stream_name: stream_name,
                       snapshot: snapshot,
                       version: version,
                       expected_version: expected_version
                     }}
                  )
                end,
                delete_snapshots: fn stream_name, version ->
                  GenServer.call(
                    pid,
                    {:delete_snapshots, %{stream_name: stream_name, version: version}}
                  )
                end
              }
          end

        entity_state =
          initialize_state(id) |> Map.put(:event_bus, event_bus) |> Map.put(:version, 0)

        {:ok, entity_state, {:continue, :initialize_events}}
      end

      def handle_continue(
            :initialize_events,
            %{id: id, event_bus: event_bus, state: state, behavior: behavior} = entity_state
          ) do
        {new_state, new_behavior, version} =
          case event_bus.load_snapshot.(get_stream_name(id), :max) do
            {:ok, nil} ->
              {:ok, version, events} = event_bus.load_events.(get_stream_name(id), :start, :all)

              {new_state, new_behavior} = run_event_handlers(events, state, behavior)

              {new_state, new_behavior, version}

            {:ok,
             %SnapshotData{payload: payload, meta_data: meta_data, version: version} = snapshot} ->
              {new_state, new_behavior} = run_snapshot_handler(snapshot, entity_state)

              {:ok, version, events} = event_bus.load_events.(get_stream_name(id), version, :all)

              {new_state, new_behavior} = run_event_handlers(events, new_state, new_behavior)

              {new_state, new_behavior, version}
          end

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
          event_bus.append_events.(
            get_stream_name(id),
            events |> Enum.map(fn event -> {event, get_event_meta_data(event)} end),
            version
          )

        {new_state, new_behavior} = run_event_handlers(stored_events, state, behavior)

        {%{entity_state | state: new_state, behavior: new_behavior, version: version},
         stored_events}
      end

      defp run_event_applier(
             %EventData{
               payload: payload,
               meta_data: meta_data,
               sequence_number: sequence_number
             },
             state
           ) do
        apply_event(payload, state, Map.put(meta_data, :sequence_number, sequence_number))
      end

      defp run_snapshot_handler(
             %SnapshotData{payload: payload, meta_data: meta_data, version: version},
             %{state: state, behavior: behavior}
           ) do
        response = apply_snapshot(payload, state, Map.put(meta_data, :version, version))

        case response do
          {new_state, nil} -> {new_state, __MODULE__}
          {new_state, new_behavior} -> {new_state, new_behavior}
          new_state -> {new_state, behavior}
        end
      end

      defp cleanup(
             %EventData{
               payload: payload,
               meta_data: meta_data,
               sequence_number: sequence_number
             },
             entity_state
           ) do
        cleanup(payload, entity_state, Map.put(meta_data, :sequence_number, sequence_number))
      end

      defp run_cleanup({:delete_events, version}, current_return, %{id: id, event_bus: event_bus}) do
        :ok = event_bus.delete_events.(get_stream_name(id), version)

        current_return
      end

      defp run_cleanup({:take_snapshot, {snapshot, version}}, current_return, _entity_state) do
        take_snapshot = fn %{id: id, event_bus: event_bus, version: current_version, state: state} =
                             entity_state ->
          {:ok, stored_snapshot} =
            event_bus.append_snapshot.(
              get_stream_name(id),
              {snapshot, get_snapshot_meta_data(snapshot)},
              version,
              current_version
            )

          {new_state, new_behavior} = run_snapshot_handler(stored_snapshot, entity_state)

          %{entity_state | state: new_state, behavior: new_behavior}
        end

        case current_return do
          {:reply, reply, entity_state} ->
            {:reply, reply, take_snapshot.(entity_state)}

          {:reply, reply, entity_state, timeout} ->
            {:reply, reply, take_snapshot.(entity_state), timeout}

          {:noreply, entity_state} ->
            {:noreply, take_snapshot.(entity_state)}

          {:noreply, entity_state, timeout} ->
            {:noreply, take_snapshot.(entity_state), timeout}

          {:stop, reason, reply, entity_state} ->
            {:stop, reason, reply, take_snapshot.(entity_state)}

          {:stop, reason, entity_state} ->
            {:stop, reason, take_snapshot.(entity_state)}
        end
      end

      defp run_cleanup({:delete_snapshots, version}, current_return, %{
             id: id,
             event_bus: event_bus
           }) do
        :ok = event_bus.delete_snapshots.(get_stream_name(id), version)

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

      defp get_snapshot_meta_data(_snapshot), do: %{}

      defoverridable get_snapshot_meta_data: 1

      defp apply_event(event, state, _meta_data), do: apply_event(event, state)

      defp cleanup(event, state, _meta_data), do: cleanup(event, state)

      defp apply_snapshot(snapshot, state, _meta_data), do: apply_snapshot(snapshot, state)

      defp apply_snapshot(_snapshot, state), do: state
    end
  end
end
