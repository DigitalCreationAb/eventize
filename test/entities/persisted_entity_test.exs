defmodule PersistedEntityTest do
  use ExUnit.Case
  doctest Eventize.Entities.PersistedEntity

  defmodule PersistedEntityTestEventBus do
    @moduledoc false

    def load_events(stream_name, start \\ :start, max_count \\ :all) do
      GenServer.call(
        Eventize.Persistence.EventStore,
        {:load_events,
         %{
           stream_name: stream_name,
           start: start,
           max_count: max_count
         }}
      )
    end

    def append_events(stream_name, events, expected_version \\ :any) do
      GenServer.call(
        Eventize.Persistence.EventStore,
        {:append_events,
         %{
           stream_name: stream_name,
           events: events,
           expected_version: expected_version
         }}
      )
    end

    def delete_events(stream_name, version) do
      GenServer.call(
        Eventize.Persistence.EventStore,
        {:delete_events, %{stream_name: stream_name, version: version}}
      )
    end

    def load_snapshot(stream_name, max_version \\ :max) do
      GenServer.call(
        Eventize.Persistence.EventStore,
        {:load_snapshot, %{stream_name: stream_name, max_version: max_version}}
      )
    end

    def append_snapshot(stream_name, snapshot, version, expected_version \\ :any) do
      GenServer.call(
        Eventize.Persistence.EventStore,
        {:append_snapshot,
         %{
           stream_name: stream_name,
           snapshot: snapshot,
           version: version,
           expected_version: expected_version
         }}
      )
    end

    def delete_snapshots(stream_name, version) do
      GenServer.call(
        Eventize.Persistence.EventStore,
        {:delete_snapshots, %{stream_name: stream_name, version: version}}
      )
    end
  end

  describe "When starting entity then stopping before getting the state" do
    setup do
      entity_id = UUID.uuid4()

      {:ok, pid} =
        TestPersistedEntityWithoutBehavior.start_link(%{
          id: entity_id,
          event_bus: Eventize.Persistence.EventStore
        })

      GenServer.call(pid, {:execute, {:start, %{title: "test"}}})

      GenServer.stop(pid)

      {:ok, pid} =
        TestPersistedEntityWithoutBehavior.start_link(%{
          id: entity_id,
          event_bus: Eventize.Persistence.EventStore
        })

      response = GenServer.call(pid, {:execute, :get_title})

      {:ok, response: response}
    end

    test "then response should have correct title", state do
      assert state.response.title == "test"
    end
  end

  describe "When starting entity then getting the state" do
    setup do
      entity_id = UUID.uuid4()

      {:ok, pid} =
        TestPersistedEntityWithoutBehavior.start_link(%{
          id: entity_id,
          event_bus: Eventize.Persistence.EventStore
        })

      GenServer.call(pid, {:execute, {:start, %{title: "test"}}})

      response = GenServer.call(pid, {:execute, :get_title})

      {:ok, response: response}
    end

    test "then response should have correct title", state do
      assert state.response.title == "test"
    end
  end

  describe "When starting entity and deleting previous events" do
    setup do
      entity_id = UUID.uuid4()

      {:ok, pid} =
        TestPersistedEntityWithoutBehavior.start_link(%{
          id: entity_id,
          event_bus: Eventize.Persistence.EventStore
        })

      GenServer.call(pid, {:execute, {:start, %{title: "test"}}})

      GenServer.call(pid, {:execute, :delete_previous})

      {:ok, stored_version, stored_events} =
        PersistedEntityTestEventBus.load_events("testpersistedentitywithoutbehavior-#{entity_id}")

      {:ok, stored_version: stored_version, stored_events: stored_events}
    end

    test "then one event should be in store for entity", state do
      assert length(state.stored_events) == 1
    end

    test "then stored version is 2", state do
      assert state.stored_version == 2
    end
  end

  describe "When handling a command that results in a event that takes a snapshot" do
    setup do
      entity_id = UUID.uuid4()

      {:ok, pid} =
        TestPersistedEntityWithoutBehavior.start_link(%{
          id: entity_id,
          event_bus: Eventize.Persistence.EventStore
        })

      GenServer.call(pid, {:execute, {:start, %{title: "test"}}})

      GenServer.call(pid, {:execute, :take_snapshot})

      {:ok, stored_version, stored_events} =
        PersistedEntityTestEventBus.load_events("testpersistedentitywithoutbehavior-#{entity_id}")

      {:ok, snapshot_data} =
        PersistedEntityTestEventBus.load_snapshot(
          "testpersistedentitywithoutbehavior-#{entity_id}"
        )

      {:ok,
       stored_version: stored_version,
       stored_events: stored_events,
       stored_snapshot: snapshot_data}
    end

    test "then two events should be in store for entity", state do
      assert length(state.stored_events) == 2
    end

    test "then stored version is 2", state do
      assert state.stored_version == 2
    end

    test "then snapshot should have correct title", state do
      assert %Eventize.Persistence.EventStore.SnapshotData{
               payload: {:entity_snapshot, %{title: "test"}}
             } = state.stored_snapshot
    end

    test "then snapshot version should be 2", state do
      assert %Eventize.Persistence.EventStore.SnapshotData{
               version: 2
             } = state.stored_snapshot
    end
  end

  describe "When handling a command twice that results in a event that takes a snapshot" do
    setup do
      entity_id = UUID.uuid4()

      {:ok, pid} =
        TestPersistedEntityWithoutBehavior.start_link(%{
          id: entity_id,
          event_bus: Eventize.Persistence.EventStore
        })

      GenServer.call(pid, {:execute, {:start, %{title: "test1"}}})

      GenServer.call(pid, {:execute, :take_snapshot})

      GenServer.call(pid, {:execute, {:start, %{title: "test2"}}})

      GenServer.call(pid, {:execute, :take_snapshot})

      {:ok, stored_version, stored_events} =
        PersistedEntityTestEventBus.load_events("testpersistedentitywithoutbehavior-#{entity_id}")

      {:ok, snapshot_data} =
        PersistedEntityTestEventBus.load_snapshot(
          "testpersistedentitywithoutbehavior-#{entity_id}"
        )

      {:ok,
       id: entity_id,
       stored_version: stored_version,
       stored_events: stored_events,
       stored_snapshot: snapshot_data}
    end

    test "then four events should be in store for entity", state do
      assert length(state.stored_events) == 4
    end

    test "then stored version should be 4", state do
      assert state.stored_version == 4
    end

    test "then snapshot should have correct title", state do
      assert %Eventize.Persistence.EventStore.SnapshotData{
               payload: {:entity_snapshot, %{title: "test2"}}
             } = state.stored_snapshot
    end

    test "then snapshot version should be 4", state do
      assert %Eventize.Persistence.EventStore.SnapshotData{
               version: 4
             } = state.stored_snapshot
    end

    test "then one snapshot should still be in event store", state do
      %Eventize.Persistence.InMemoryEventStore.State{snapshots: snapshots} =
        :sys.get_state(Eventize.Persistence.EventStore)

      assert length(Map.get(snapshots, "testpersistedentitywithoutbehavior-#{state.id}")) == 1
    end
  end
end
