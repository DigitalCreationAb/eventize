defmodule EventSourcedProcess.StateTest do
  use Eventize.Test.EventSourcedProcessTests, Eventize.StateTestProcess

  describe "When calling to set new state" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id)

      response = GenServer.call(pid, {:set_state, %{test: "Test"}})

      {:ok, pid: pid, id: id, response: response}
    end

    test "then response should be :ok", state do
      assert state.response == :ok
    end

    test "then one event should be stored", state do
      assert length(get_events(state.id)) == 1
    end

    test "then a :state_set event should be stored", state do
      assert [{:state_set, %{test: "Test"}}] = get_events(state.id) |> get_payload()
    end

    test "then process version should be 1", state do
      assert get_process_version(state.id) == 1
    end

    test "then process should be in default behavior", state do
      assert get_current_behavior(state.pid) == Eventize.StateTestProcess
    end

    test "then process should have correct state", state do
      assert get_process_state(state.pid) == %{test: "Test"}
    end
  end

  describe "When casting to set new state" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id)

      GenServer.cast(pid, {:set_state, %{test: "Test"}})

      :pong = GenServer.call(pid, :ping)

      {:ok, pid: pid, id: id}
    end

    test "then one event should be stored", state do
      assert length(get_events(state.id)) == 1
    end

    test "then a :state_set event should be stored", state do
      assert [{:state_set, %{test: "Test"}}] = get_events(state.id) |> get_payload()
    end

    test "then process version should be 1", state do
      assert get_process_version(state.id) == 1
    end

    test "then process should be in default behavior", state do
      assert get_current_behavior(state.pid) == Eventize.StateTestProcess
    end

    test "then process should have correct state", state do
      assert get_process_state(state.pid) == %{test: "Test"}
    end
  end
end
