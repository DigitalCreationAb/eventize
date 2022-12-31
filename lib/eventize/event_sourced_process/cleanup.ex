defmodule Eventize.EventSourcedProcess.Cleanup do
  @moduledoc """
  A module that impliments the cleanup for a
  `Eventize.EventSourcedProcess`.
  """

  alias Eventize.EventSourcedProcessState

  @callback cleanup(term(), term()) :: list() | term()

  @callback cleanup(term(), term(), map()) :: list() | term()

  @optional_callbacks cleanup: 2,
                      cleanup: 3

  def run_cleanup(:stop, current_return, process_state),
    do: run_cleanup({:stop, :normal}, current_return, process_state)

  def run_cleanup({:stop, reason}, current_return, _process_state) do
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

  def run_cleanup({:timeout, timeout}, current_return, _process_state) do
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

  def run_cleanup(:hibernate, current_return, _process_state) do
    case current_return do
      {:reply, reply, new_state} ->
        {:reply, reply, new_state, :hibernate}

      {:noreply, new_state} ->
        {:noreply, new_state, :hibernate}

      _ ->
        current_return
    end
  end

  def run_cleanup({:continue, _data} = continuation, current_return, _process_state) do
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

  def run_cleanup({:delete_events, version}, current_return, %EventSourcedProcessState{
        event_bus: event_bus,
        stream_name: stream_name
      }) do
    :ok = event_bus.delete_events.(stream_name, version)

    current_return
  end

  def run_cleanup({:take_snapshot, {snapshot, version}}, current_return, _process_state) do
    take_snapshot = fn %EventSourcedProcessState{
                         event_bus: event_bus,
                         version: current_version,
                         stream_name: stream_name,
                         process: process
                       } = process_state ->
      {:ok, stored_snapshot} =
        event_bus.append_snapshot.(
          stream_name,
          {snapshot, process.get_snapshot_meta_data(snapshot)},
          version,
          current_version
        )

      {new_state, new_behavior} = process.run_snapshot_handler(stored_snapshot, process_state)

      %EventSourcedProcessState{process_state | state: new_state, behavior: new_behavior}
    end

    case current_return do
      {:reply, reply, process_state} ->
        {:reply, reply, take_snapshot.(process_state)}

      {:reply, reply, process_state, timeout} ->
        {:reply, reply, take_snapshot.(process_state), timeout}

      {:noreply, process_state} ->
        {:noreply, take_snapshot.(process_state)}

      {:noreply, process_state, timeout} ->
        {:noreply, take_snapshot.(process_state), timeout}

      {:stop, reason, reply, process_state} ->
        {:stop, reason, reply, take_snapshot.(process_state)}

      {:stop, reason, process_state} ->
        {:stop, reason, take_snapshot.(process_state)}
    end
  end

  def run_cleanup({:delete_snapshots, version}, current_return, %EventSourcedProcessState{
        event_bus: event_bus,
        stream_name: stream_name
      }) do
    :ok = event_bus.delete_snapshots.(stream_name, version)

    current_return
  end

  def run_cleanup(_cleanup, current_return, _process_state), do: current_return

  defmacro __using__(_) do
    quote location: :keep, generated: true do
      @behaviour Eventize.EventSourcedProcess.Cleanup

      @before_compile Eventize.EventSourcedProcess.Cleanup

      @doc false
      @impl GenServer
      def handle_info(:timeout, state) do
        {:stop, :normal, state}
      end

      def handle_cleanup({entity_state, events}, default_return) do
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
          Eventize.EventSourcedProcess.Cleanup.run_cleanup(
            cleanup,
            current_response,
            entity_state
          )
        end)
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def cleanup(
            %Eventize.Persistence.EventStore.EventData{
              payload: payload,
              meta_data: meta_data,
              sequence_number: sequence_number
            },
            entity_state
          ) do
        cleanup(payload, entity_state, Map.put(meta_data, :sequence_number, sequence_number))
      end

      def cleanup(_event, _state), do: []

      def cleanup(event, state, _meta_data), do: cleanup(event, state)

      defoverridable cleanup: 2,
                     cleanup: 3
    end
  end
end
