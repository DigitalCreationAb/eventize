defmodule Eventize.Test.EventSourcedProcessTests do
  @moduledoc false

  defmodule EventStoreTestEventBus do
    @moduledoc false

    def load_events(pid, stream_name, start \\ :start, max_count \\ :all) do
      GenServer.call(
        pid,
        {:load_events,
         %{
           stream_name: stream_name,
           start: start,
           max_count: max_count
         }}
      )
    end

    def append_events(pid, stream_name, events, expected_version \\ :any) do
      GenServer.call(
        pid,
        {:append_events,
         %{
           stream_name: stream_name,
           events: events,
           expected_version: expected_version
         }}
      )
    end

    def delete_events(pid, stream_name, version) do
      GenServer.call(
        pid,
        {:delete_events, %{stream_name: stream_name, version: version}}
      )
    end

    def load_snapshot(pid, stream_name, max_version \\ :max) do
      GenServer.call(
        pid,
        {:load_snapshot, %{stream_name: stream_name, max_version: max_version}}
      )
    end

    def append_snapshot(pid, stream_name, snapshot, version, expected_version \\ :any) do
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
    end

    def delete_snapshots(pid, stream_name, version) do
      GenServer.call(
        pid,
        {:delete_snapshots, %{stream_name: stream_name, version: version}}
      )
    end
  end

  defmacro __using__(process_type) do
    quote do
      use ExUnit.Case
      doctest Eventize.EventSourcedProcess

      alias Eventize.Persistence.InMemoryEventStore
      alias Eventize.Test.EventSourcedProcessTests.EventStoreTestEventBus
      alias Eventize.Persistence.EventStore.EventData
      alias Eventize.Persistence.EventStore.SnapshotData

      @event_store_name String.to_atom("#{__MODULE__}TestEventStore")

      setup_all do
        start_supervised({InMemoryEventStore, name: @event_store_name})

        :ok
      end

      defp get_process(), do: get_process([])

      defp get_process(initial_events) when is_list(initial_events),
        do: get_process(UUID.uuid4(), initial_events)

      defp get_process(id) when is_binary(id), do: get_process(id, [], nil)

      defp get_process(id, {_, _, _} = initial_snapshot),
        do: get_process(id, [], initial_snapshot)

      defp get_process(id, initial_events, nil), do: get_process(id, initial_events)

      defp get_process(id, initial_events, {snapshot, meta_data, version}) do
        {:ok, _} =
          EventStoreTestEventBus.append_snapshot(
            @event_store_name,
            get_stream_name(id),
            {snapshot, meta_data},
            version
          )

        get_process(id, initial_events)
      end

      defp get_process(id, initial_events) when is_list(initial_events) do
        {:ok, _} =
          EventStoreTestEventBus.append_events(
            @event_store_name,
            get_stream_name(id),
            initial_events |> Enum.map(fn event -> {event, %{}} end)
          )

        {:ok, pid} = start_process(id)

        pid
      end

      defp start_process(id) do
        unquote(process_type).start_link(%{
          id: id,
          event_bus: @event_store_name
        })
      end

      defoverridable start_process: 1

      defp get_stream_name(id) do
        [module_name | _] =
          Atom.to_string(unquote(process_type))
          |> String.split(".")
          |> Enum.take(-1)

        "#{String.downcase(module_name)}-#{id}"
      end

      defoverridable get_stream_name: 1

      defp get_events(id, from \\ :start) do
        {:ok, events} =
          EventStoreTestEventBus.load_events(@event_store_name, get_stream_name(id), from)

        events
      end

      defp get_snapshot(id, max_version \\ :max) do
        {:ok, snapshot} =
          EventStoreTestEventBus.load_snapshot(
            @event_store_name,
            get_stream_name(id),
            max_version
          )

        snapshot
      end

      defp get_payload(%SnapshotData{payload: payload}) do
        payload
      end

      defp get_payload(%EventData{payload: payload}) do
        payload
      end

      defp get_payload(nil) do
        nil
      end

      defp get_payload(events) when is_list(events) do
        events |> Enum.map(fn event -> get_payload(event) end)
      end

      defp get_payload(payload) do
        payload
      end

      defp get_meta_data(%SnapshotData{meta_data: meta_data}) do
        meta_data
      end

      defp get_meta_data(%EventData{meta_data: meta_data}) do
        meta_data
      end

      defp get_meta_data(nil) do
        nil
      end

      defp get_meta_data(events) do
        events |> Enum.map(fn event -> get_meta_data(event) end)
      end

      defp get_process_version(pid) do
        state = :sys.get_state(pid)

        state.version
      end

      defp get_current_behavior(pid) do
        state = :sys.get_state(pid)

        state.behavior
      end

      defp get_process_state(pid) do
        state = :sys.get_state(pid)

        state.state
      end
    end
  end
end
