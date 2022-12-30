defmodule EventSourcedProcess.StopCleanupTest do
  use Eventize.Test.EventSourcedProcessTests, Eventize.StopCleanupTestProcess

  describe "When calling to request stop" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id)

      response =
        GenServer.call(
          pid,
          :stop
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

    test "then a :stop_requested event should be stored", state do
      assert [{:stop_requested, _}] = get_events(state.id) |> get_payload()
    end

    test "then process should be stopped", state do
      assert Process.info(state.pid) == nil
    end
  end
end
