defmodule Eventize.EventSourcedProcess do
  @moduledoc """
  EventSourcedProcess is a `EventizeEntity` that will
  use event sourcing to store its applied events.
  """

  @doc """
  A callback used when the entity is starting up.
  """
  @callback start(id :: String.t()) :: {:atom, map()} | :atom | map() | nil

  defmacro __using__(_) do
    quote location: :keep do
      use GenServer
      alias Eventize.Persistence.EventStore
      alias Eventize.Persistence.EventStore.EventData
      alias Eventize.Persistence.EventStore.SnapshotData

      @before_compile Eventize.EventSourcedProcess
      @behaviour Eventize.EventSourcedProcess

      @doc """
      Initializes the EventSourcedProcess with the initial state.
      Then it uses `:continue` to read the events from the
      `Eventize.Persistence.EventStore` in the background.
      """
      def init(%{id: id, event_bus: event_bus}) do
        event_bus = Eventize.Persistence.EventStore.parse_event_bus(event_bus)

        entity_state =
          case start(id) do
            nil ->
              %{behavior: __MODULE__, state: nil}

            {behavior, initial_state} when is_atom(behavior) ->
              %{behavior: behavior, state: initial_state}

            behavior when is_atom(behavior) ->
              %{behavior: behavior, state: nil}

            initial_state ->
              %{behavior: __MODULE__, state: initial_state}
          end
          |> Map.put(:id, id)
          |> Map.put(:event_bus, event_bus)
          |> Map.put(:version, 0)

        {:ok, entity_state, {:continue, :initialize_events}}
      end

      def init(%{id: id} = data), do: init(Map.put(data, :event_bus, nil))

      @doc """
      This continuation will run right after starting the process and is used to load the state of the entity from the event store.
      """
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
             %SnapshotData{payload: _payload, meta_data: _meta_data, version: version} = snapshot} ->
              {new_state, new_behavior} = run_snapshot_handler(snapshot, entity_state)

              {:ok, version, events} = event_bus.load_events.(get_stream_name(id), version, :all)

              {new_state, new_behavior} = run_event_handlers(events, new_state, new_behavior)

              {new_state, new_behavior, version}
          end

        {:noreply, %{entity_state | behavior: new_behavior, state: new_state, version: version}}
      end

      @doc """
      Handle any command sent to the entity.
      """
      def handle_cast(
            {command, %{message_id: message_id, correlation_id: correlation_id}},
            %{id: id, state: state, behavior: behavior} = entity_state
          ) do
        {new_state, events} =
          case behavior.execute_cast(command, %{
                 id: id,
                 state: state,
                 causation_id: message_id,
                 correlation_id: correlation_id
               }) do
            events when is_list(events) ->
              apply_events(events, entity_state, %{
                causation_id: message_id,
                correlation_id: correlation_id
              })

            _ ->
              {entity_state, []}
          end

        handle_cleanup({new_state, events}, {:noreply, new_state})
      end

      def handle_cast({command, %{message_id: message_id}}, entity_state),
        do:
          handle_cast(
            {command, %{message_id: message_id, correlation_id: UUID.uuid4()}},
            entity_state
          )

      def handle_cast({command, %{correlation_id: correlation_id}}, entity_state),
        do:
          handle_cast(
            {command, %{message_id: UUID.uuid4(), correlation_id: correlation_id}},
            entity_state
          )

      def handle_cast(command, entity_state),
        do:
          handle_cast(
            {command, %{message_id: UUID.uuid4(), correlation_id: UUID.uuid4()}},
            entity_state
          )

      @doc """
      Handle any command sent to the entity where the sender wants a response back.
      """
      def handle_call(
            {command, %{message_id: message_id, correlation_id: correlation_id}},
            from,
            %{id: id, state: state, behavior: behavior} = entity_state
          ) do
        {response, new_state, events} =
          case behavior.execute_call(command, from, %{
                 id: id,
                 state: state,
                 causation_id: message_id,
                 correlation_id: correlation_id
               }) do
            {events, response} when is_list(events) ->
              {state, events} =
                apply_events(events, entity_state, %{
                  causation_id: message_id,
                  correlation_id: correlation_id
                })

              {response, state, events}

            events when is_list(events) ->
              {state, events} =
                apply_events(events, entity_state, %{
                  causation_id: message_id,
                  correlation_id: correlation_id
                })

              {:ok, state, events}

            response ->
              {response, entity_state, []}
          end

        handle_cleanup({new_state, events}, {:reply, response, new_state})
      end

      def handle_call({command, %{message_id: message_id}}, from, entity_state),
        do:
          handle_call(
            {command, %{message_id: message_id, correlation_id: UUID.uuid4()}},
            from,
            entity_state
          )

      def handle_call({command, %{correlation_id: correlation_id}}, from, entity_state),
        do:
          handle_call(
            {command, %{message_id: UUID.uuid4(), correlation_id: correlation_id}},
            from,
            entity_state
          )

      def handle_call(command, from, entity_state),
        do:
          handle_call(
            {command, %{message_id: UUID.uuid4(), correlation_id: UUID.uuid4()}},
            from,
            entity_state
          )

      @doc """
      Stops the entity after the desired timeout.
      """
      def handle_info(:timeout, state) do
        {:stop, :normal, state}
      end

      defp handle_cleanup({entity_state, events}, default_return) do
        events
        |> Enum.map(fn event -> cleanup(event, entity_state.state) end)
        |> Enum.map(fn cleanup_data ->
          case cleanup_data do
            list when is_list(list) ->
              list

            item ->
              [item]
          end
        end)
        |> Enum.concat()
        |> Enum.reduce(default_return, fn cleanup, current_response ->
          run_cleanup(cleanup, current_response, entity_state)
        end)
      end

      defp apply_events(
             events,
             %{
               id: id,
               state: state,
               behavior: behavior,
               event_bus: event_bus,
               version: version
             } = entity_state,
             %{} = additional_meta_data
           )
           when is_list(events) do
        {:ok, version, stored_events} =
          event_bus.append_events.(
            get_stream_name(id),
            events
            |> Enum.map(fn event ->
              {event, Map.merge(additional_meta_data, get_event_meta_data(event))}
            end),
            version
          )

        {new_state, new_behavior} = run_event_handlers(stored_events, state, behavior)

        {%{entity_state | state: new_state, behavior: new_behavior, version: version},
         stored_events}
      end

      defp run_event_handlers(events, state, current_behavior) when is_list(events) do
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

      defp run_cleanup(:stop, current_return, entity_state),
        do: run_cleanup({:stop, :normal}, current_return, entity_state)

      defp run_cleanup({:stop, reason}, current_return, _entity_state) do
        case current_return do
          {:reply, reply, new_state} ->
            {:stop, reason, reply, new_state}

          {:reply, reply, new_state, _} ->
            {:stop, reason, reply, new_state}

          {:noreply, new_state} ->
            {:stop, reason, new_state}

          {:noreply, new_state, _} ->
            {:stop, reason, new_state}

          {:stop, _, reply, new_state} ->
            {:stop, reason, reply, new_state}

          {:stop, _, new_state} ->
            {:stop, reason, new_state}
        end
      end

      defp run_cleanup({:timeout, timeout}, current_return, _entity_state) do
        case current_return do
          {:reply, reply, new_state} ->
            {:reply, reply, new_state, timeout}

          {:reply, reply, new_state, current_timeout}
          when (is_integer(current_timeout) and timeout < current_timeout) or
                 current_timeout == :hibernate ->
            {:reply, reply, new_state, timeout}

          {:noreply, new_state} ->
            {:noreply, new_state, timeout}

          {:noreply, new_state, current_timeout}
          when (is_integer(current_timeout) and timeout < current_timeout) or
                 current_timeout == :hibernate ->
            {:noreply, new_state, timeout}

          _ ->
            current_return
        end
      end

      defp run_cleanup(:hibernate, current_return, _entity_state) do
        case current_return do
          {:reply, reply, new_state} ->
            {:reply, reply, new_state, :hibernate}

          {:noreply, new_state} ->
            {:noreply, new_state, :hibernate}

          _ ->
            current_return
        end
      end

      defp run_cleanup({:continue, _data} = continuation, current_return, _entity_state) do
        case current_return do
          {:reply, reply, new_state} ->
            {:reply, reply, new_state, continuation}

          {:reply, reply, new_state, _current_timeout} ->
            {:reply, reply, new_state, continuation}

          {:noreply, new_state} ->
            {:noreply, new_state, continuation}

          {:noreply, new_state, _current_timeout} ->
            {:noreply, new_state, continuation}

          _ ->
            current_return
        end
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
      def start(_id), do: %{}

      defoverridable start: 1

      defp get_event_meta_data(_event), do: %{}

      defoverridable get_event_meta_data: 1

      defp get_snapshot_meta_data(_snapshot), do: %{}

      defoverridable get_snapshot_meta_data: 1

      defp apply_event(_event, state), do: state

      defp apply_event(event, state, _meta_data), do: apply_event(event, state)

      defp run_cleanup(_cleanup, current_return, _state), do: current_return

      defp cleanup(_event, _state), do: []

      defp cleanup(event, state, _meta_data), do: cleanup(event, state)

      defp apply_snapshot(snapshot, state, _meta_data), do: apply_snapshot(snapshot, state)

      defp apply_snapshot(_snapshot, state), do: state
    end
  end
end
