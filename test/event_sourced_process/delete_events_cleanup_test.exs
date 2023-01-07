defmodule EventSourcedProcess.DeleteEventsCleanupTest do
  use Eventize.Test.EventSourcedProcessTests, Eventize.DeleteEventsCleanupTestProcess

  describe "When calling to delete all events with previous events stored" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id, [{:test_event, %{}}])

      response =
        GenServer.call(
          pid,
          {:delete_events, :all}
        )

      {:ok, pid: pid, id: id, response: response}
    end

    test "then response should be :ok", state do
      assert state.response == :ok
    end

    test "then no events should be stored", state do
      assert get_events(state.id) == []
    end

    test "then process should be in default behavior", state do
      assert get_current_behavior(state.pid) == Eventize.DeleteEventsCleanupTestProcess
    end
  end

  describe "When calling to delete previous events" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id, [{:test_event, %{}}])

      response =
        GenServer.call(
          pid,
          {:delete_events, 0}
        )

      {:ok, pid: pid, id: id, response: response}
    end

    test "then response should be :ok", state do
      assert state.response == :ok
    end

    test "then one event should be stored", state do
      assert length(get_events(state.id)) == 1
    end

    test "then a :delete_requested event should be stored", state do
      assert [{:delete_requested, 0}] = get_events(state.id) |> get_payload()
    end

    test "then process should be in default behavior", state do
      assert get_current_behavior(state.pid) == Eventize.DeleteEventsCleanupTestProcess
    end
  end

  describe "When casting to delete all events with previous events stored" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id, [{:test_event, %{}}])

      GenServer.cast(
        pid,
        {:delete_events, :all}
      )

      :pong = GenServer.call(pid, :ping)

      {:ok, pid: pid, id: id}
    end

    test "then no events should be stored", state do
      assert get_events(state.id) == []
    end

    test "then process should be in default behavior", state do
      assert get_current_behavior(state.pid) == Eventize.DeleteEventsCleanupTestProcess
    end
  end

  describe "When casting to delete previous events" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id, [{:test_event, %{}}])

      GenServer.call(
        pid,
        {:delete_events, 0}
      )

      :pong = GenServer.call(pid, :ping)

      {:ok, pid: pid, id: id}
    end

    test "then one event should be stored", state do
      assert length(get_events(state.id)) == 1
    end

    test "then a :delete_requested event should be stored", state do
      assert [{:delete_requested, 0}] = get_events(state.id) |> get_payload()
    end

    test "then process should be in default behavior", state do
      assert get_current_behavior(state.pid) == Eventize.DeleteEventsCleanupTestProcess
    end
  end
end
