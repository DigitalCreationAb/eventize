defmodule EventSourcedProcess.TimeoutCleanupTest do
  use Eventize.Test.EventSourcedProcessTests, Eventize.TimeoutCleanupTestProcess

  describe "When calling to request timeout" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id)

      response = GenServer.call(
        pid,
        {:timeout, 1}
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

    test "then a :timeout_requested event should be stored", state do
      assert [{:timeout_requested, _}] = get_events(state.id) |> get_payload()
    end

    test "then process should be stopped after timeout", state do
      Process.sleep(1)

      assert Process.info(state.pid) == nil
    end
  end
end
