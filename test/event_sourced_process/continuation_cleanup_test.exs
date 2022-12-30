defmodule EventSourcedProcess.ContinuationCleanupTest do
  use Eventize.Test.EventSourcedProcessTests, Eventize.ContinuationCleanupTestProcess

  describe "When calling to set state in continuation" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id)

      response = GenServer.call(pid, {:set_state_in_continuation, %{test: "Test"}})

      {:ok, pid: pid, id: id, response: response}
    end

    test "then response should be :ok", state do
      assert state.response == :ok
    end

    test "then one event should be stored", state do
      assert length(get_events(state.id)) == 1
    end

    test "then a :continuation_requested event should be stored", state do
      assert [{:continuation_requested, %{test: "Test"}}] = get_events(state.id) |> get_payload()
    end

    test "then process version should be 1", state do
      assert get_process_version(state.id) == 1
    end

    test "then process should be in default behavior", state do
      assert get_current_behavior(state.pid) == Eventize.ContinuationCleanupTestProcess
    end

    test "then process should have correct state", state do
      assert get_process_state(state.pid) == %{test: "Test"}
    end
  end

  describe "When casting to set state in continuation" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id)

      GenServer.cast(pid, {:set_state_in_continuation, %{test: "Test"}})

      :pong = GenServer.call(pid, :ping)

      {:ok, pid: pid, id: id}
    end

    test "then one event should be stored", state do
      assert length(get_events(state.id)) == 1
    end

    test "then a :continuation_requested event should be stored", state do
      assert [{:continuation_requested, %{test: "Test"}}] = get_events(state.id) |> get_payload()
    end

    test "then process version should be 1", state do
      assert get_process_version(state.id) == 1
    end

    test "then process should be in default behavior", state do
      assert get_current_behavior(state.pid) == Eventize.ContinuationCleanupTestProcess
    end

    test "then process should have correct state", state do
      assert get_process_state(state.pid) == %{test: "Test"}
    end
  end
end
