defmodule EventSourcedProcess.HibernateCleanupTest do
  use Eventize.Test.EventSourcedProcessTests, Eventize.HibernateCleanupTestProcess

  describe "When calling to request hibernation" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id)

      response =
        GenServer.call(
          pid,
          :hibernate
        )

      {:ok, pid: pid, id: id, response: response}
    end

    test "then response should be :ok", state do
      assert state.response == :ok
    end

    test "then one event should be stored", state do
      assert length(get_events(state.id)) == 1
    end

    test "then process version should be 0", state do
      assert get_process_version(state.pid) == 0
    end

    test "then a :hibernation_requested event should be stored", state do
      assert [{:hibernation_requested, _}] = get_events(state.id) |> get_payload()
    end

    test "then process should be in default behavior", state do
      assert get_current_behavior(state.pid) == Eventize.HibernateCleanupTestProcess
    end

    test "then process should be hibernating", state do
      assert {:current_function, {:erlang, :hibernate, _}} =
               Process.info(state.pid, :current_function)
    end
  end
end
