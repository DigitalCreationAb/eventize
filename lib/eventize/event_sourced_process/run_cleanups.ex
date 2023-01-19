defmodule Eventize.EventSourcedProcess.RunCleanups do
  @moduledoc false

  defmodule CleanupContext do
    @moduledoc false

    @type t :: %__MODULE__{
            state: term(),
            meta_data: map(),
            sequence_number: non_neg_integer()
          }

    defstruct [:state, :meta_data, :sequence_number]
  end

  alias Eventize.EventSourcedProcess.ExecutionPipeline.ExecutionContext
  alias Eventize.EventSourcedProcessState

  @behaviour Eventize.EventSourcedProcess.ExecutionPipeline.PipelineStep

  @callback cleanup(term(), term()) :: list() | term()

  @callback cleanup(term(), term(), map()) :: list() | term()

  @optional_callbacks cleanup: 2,
                      cleanup: 3

  def execute(
        context,
        next
      ) do
    new_context = next.(context)

    %ExecutionContext{
      build_response: build_response,
      state:
        %Eventize.EventSourcedProcessState{
          process: process,
          state: state
        } = process_state,
      step_data: %{events: events}
    } = new_context

    new_response =
      events
      |> Enum.map(fn %Eventize.Persistence.EventStore.EventData{
                       payload: payload,
                       meta_data: meta_data,
                       sequence_number: sequence_number
                     } ->
        process.cleanup(payload, %CleanupContext{
          state: state,
          meta_data: meta_data,
          sequence_number: sequence_number
        })
      end)
      |> Enum.map(fn cleanup_data ->
        case cleanup_data do
          list when is_list(list) ->
            list

          item ->
            [item]
        end
      end)
      |> Enum.concat()
      |> Enum.reduce(build_response.(process_state), fn cleanup, current_response ->
        run_cleanup(
          cleanup,
          current_response,
          process_state
        )
      end)

    %ExecutionContext{new_context | build_response: fn _ -> new_response end}
  end

  defp run_cleanup(:stop, current_return, process_state),
    do: run_cleanup({:stop, :normal}, current_return, process_state)

  defp run_cleanup({:stop, reason}, current_return, _process_state) do
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

  defp run_cleanup({:timeout, timeout}, current_return, _process_state) do
    case current_return do
      {:reply, reply, new_state} ->
        {:reply, reply, new_state, timeout}

      {:reply, reply, new_state, current_timeout} ->
        {:reply, reply, new_state, get_new_timeout(current_timeout, timeout)}

      {:noreply, new_state} ->
        {:noreply, new_state, timeout}

      {:noreply, new_state, current_timeout} ->
        {:noreply, new_state, get_new_timeout(current_timeout, timeout)}

      _ ->
        current_return
    end
  end

  defp run_cleanup(:hibernate, current_return, _process_state) do
    case current_return do
      {:reply, reply, new_state} ->
        {:reply, reply, new_state, :hibernate}

      {:noreply, new_state} ->
        {:noreply, new_state, :hibernate}

      _ ->
        current_return
    end
  end

  defp run_cleanup({:continue, _data} = continuation, current_return, _process_state) do
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

  defp run_cleanup({:delete_events, version}, current_return, %EventSourcedProcessState{
         event_bus: event_bus,
         stream_name: stream_name
       }) do
    :ok = event_bus.delete_events.(stream_name, version)

    current_return
  end

  defp run_cleanup({:take_snapshot, {snapshot, version}}, current_return, _process_state) do
    take_snapshot = fn %EventSourcedProcessState{
                         event_bus: event_bus,
                         stream_name: stream_name,
                         process: process
                       } = process_state ->
      {:ok, stored_snapshot} =
        event_bus.append_snapshot.(
          stream_name,
          {snapshot, process.get_snapshot_meta_data(snapshot)},
          version
        )

      {new_state, new_behavior} =
        Eventize.EventSourcedProcess.LoadLatestSnapshot.run_snapshot_handler(
          stored_snapshot,
          process_state
        )

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

  defp run_cleanup({:delete_snapshots, version}, current_return, %EventSourcedProcessState{
         event_bus: event_bus,
         stream_name: stream_name
       }) do
    :ok = event_bus.delete_snapshots.(stream_name, version)

    current_return
  end

  defp run_cleanup(_cleanup, current_return, _process_state), do: current_return

  defp get_new_timeout(current_timeout, new_timeout) do
    case {current_timeout, new_timeout} do
      {:hibernate, t} ->
        t

      {c, t} when is_integer(c) and is_integer(t) and t < c ->
        t

      {c, _} ->
        c
    end
  end
end
