defmodule EventSourcedProcess.SnapshotCleanupTest do
  use Eventize.Test.EventSourcedProcessTests, Eventize.SnapshotCleanupTestProcess

  describe "When calling to take snapshot with previous events" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id, [{:state_updated, %{test: "Test"}}])

      response = GenServer.call(pid, :take_snapshot)

      {:ok, pid: pid, id: id, response: response}
    end

    test "then response should be :ok", state do
      assert state.response == :ok
    end

    test "then one new event should be stored", state do
      assert length(get_events(state.id, 1)) == 1
    end

    test "then a :snapshot_requested event should be stored", state do
      assert [{:snapshot_requested, _}] = get_events(state.id, 1) |> get_payload()
    end

    test "then process version should be 1", state do
      assert get_process_version(state.pid) == 1
    end

    test "then process should be in default behavior", state do
      assert get_current_behavior(state.pid) == Eventize.SnapshotCleanupTestProcess
    end

    test "then correct snapshot should be stored", state do
      assert {:test_snapshot, %{test: "Test"}} = get_snapshot(state.id) |> get_payload()
    end
  end

  describe "When casting to take snapshot with previous events" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id, [{:state_updated, %{test: "Test"}}])

      GenServer.cast(pid, :take_snapshot)

      :pong = GenServer.call(pid, :ping)

      {:ok, pid: pid, id: id}
    end

    test "then one new event should be stored", state do
      assert length(get_events(state.id, 1)) == 1
    end

    test "then a :snapshot_requested event should be stored", state do
      assert [{:snapshot_requested, _}] = get_events(state.id, 1) |> get_payload()
    end

    test "then process version should be 1", state do
      assert get_process_version(state.pid) == 1
    end

    test "then process should be in default behavior", state do
      assert get_current_behavior(state.pid) == Eventize.SnapshotCleanupTestProcess
    end

    test "then correct snapshot should be stored", state do
      assert {:test_snapshot, %{test: "Test"}} = get_snapshot(state.id) |> get_payload()
    end
  end
end
