defmodule EventSourcedProcess.DeleteSnapshotsCleanupTest do
  use Eventize.Test.EventSourcedProcessTests, Eventize.DeleteSnapshotsCleanupTestProcess

  describe "When calling to delete all snapshots with previous snapshot stored" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id, {{:test_snapshot, %{}}, %{}, 1})

      response =
        GenServer.call(
          pid,
          {:delete_snapshots, :all}
        )

      {:ok, pid: pid, id: id, response: response}
    end

    test "then response should be :ok", state do
      assert state.response == :ok
    end

    test "then one event should be stored", state do
      assert length(get_events(state.id)) == 1
    end

    test "then process version should be 1", state do
      assert get_process_version(state.id) == 1
    end

    test "then a :delete_requested event should be stored", state do
      assert [{:delete_requested, _}] = get_events(state.id) |> get_payload()
    end

    test "then no snapshot should be stored", state do
      assert get_snapshot(state.id) == nil
    end

    test "then process should be in default behavior", state do
      assert get_current_behavior(state.pid) == Eventize.DeleteSnapshotsCleanupTestProcess
    end
  end

  describe "When calling to delete all snapshots without snapshot stored" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id)

      response =
        GenServer.call(
          pid,
          {:delete_snapshots, :all}
        )

      {:ok, pid: pid, id: id, response: response}
    end

    test "then response should be :ok", state do
      assert state.response == :ok
    end

    test "then one event should be stored", state do
      assert length(get_events(state.id)) == 1
    end

    test "then process version should be 1", state do
      assert get_process_version(state.id) == 1
    end

    test "then a :delete_requested event should be stored", state do
      assert [{:delete_requested, _}] = get_events(state.id) |> get_payload()
    end

    test "then no snapshot should be stored", state do
      assert get_snapshot(state.id) == nil
    end

    test "then process should be in default behavior", state do
      assert get_current_behavior(state.pid) == Eventize.DeleteSnapshotsCleanupTestProcess
    end
  end

  describe "When casting to delete all snapshots with previous snapshot stored" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id, {{:test_snapshot, %{}}, %{}, 1})

      GenServer.cast(
        pid,
        {:delete_snapshots, :all}
      )

      :pong = GenServer.call(pid, :ping)

      {:ok, pid: pid, id: id}
    end

    test "then one event should be stored", state do
      assert length(get_events(state.id)) == 1
    end

    test "then process version should be 1", state do
      assert get_process_version(state.id) == 1
    end

    test "then a :delete_requested event should be stored", state do
      assert [{:delete_requested, _}] = get_events(state.id) |> get_payload()
    end

    test "then no snapshot should be stored", state do
      assert get_snapshot(state.id) == nil
    end

    test "then process should be in default behavior", state do
      assert get_current_behavior(state.pid) == Eventize.DeleteSnapshotsCleanupTestProcess
    end
  end

  describe "When casting to delete all snapshots without snapshot stored" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id)

      GenServer.cast(
        pid,
        {:delete_snapshots, :all}
      )

      :pong = GenServer.call(pid, :ping)

      {:ok, pid: pid, id: id}
    end

    test "then one event should be stored", state do
      assert length(get_events(state.id)) == 1
    end

    test "then process version should be 1", state do
      assert get_process_version(state.id) == 1
    end

    test "then a :delete_requested event should be stored", state do
      assert [{:delete_requested, _}] = get_events(state.id) |> get_payload()
    end

    test "then no snapshot should be stored", state do
      assert get_snapshot(state.id) == nil
    end

    test "then process should be in default behavior", state do
      assert get_current_behavior(state.pid) == Eventize.DeleteSnapshotsCleanupTestProcess
    end
  end
end
