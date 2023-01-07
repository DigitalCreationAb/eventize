defmodule EventSourcedProcess.BehaviorTest do
  use Eventize.Test.EventSourcedProcessTests, Eventize.BehaviorTestProcess

  describe "When calling process to enter secondary from initial" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id)

      response = GenServer.call(pid, :enter_secondary)

      {:ok, pid: pid, id: id, response: response}
    end

    test "then response should be :ok", state do
      assert state.response == :ok
    end

    test "then one event should be stored", state do
      assert length(get_events(state.id)) == 1
    end

    test "then a :seconday_behavior_entered event should be stored", state do
      assert [{:seconday_behavior_entered, _}] = get_events(state.id) |> get_payload()
    end

    test "then process version should be 0", state do
      assert get_process_version(state.pid) == 0
    end

    test "then process should be in secondary behavior", state do
      assert get_current_behavior(state.pid) == Eventize.BehaviorTestProcess.SecondaryBehavior
    end
  end

  describe "When casting process to enter secondary from initial" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id)

      GenServer.cast(pid, :enter_secondary)

      :pong = GenServer.call(pid, :ping)

      {:ok, pid: pid, id: id}
    end

    test "then one event should be stored", state do
      assert length(get_events(state.id)) == 1
    end

    test "then a :seconday_behavior_entered event should be stored", state do
      assert [{:seconday_behavior_entered, _}] = get_events(state.id) |> get_payload()
    end

    test "then process version should be 0", state do
      assert get_process_version(state.pid) == 0
    end

    test "then process should be in secondary behavior", state do
      assert get_current_behavior(state.pid) == Eventize.BehaviorTestProcess.SecondaryBehavior
    end
  end

  describe "When calling process to enter initial from secondary" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id, [{:seconday_behavior_entered, %{}}])

      response = GenServer.call(pid, :enter_initial)

      {:ok, pid: pid, id: id, response: response}
    end

    test "then response should be :ok", state do
      assert state.response == :ok
    end

    test "then one event should be stored", state do
      assert length(get_events(state.id, 1)) == 1
    end

    test "then a :initial_behavior_entered event should be stored", state do
      assert [{:initial_behavior_entered, _}] = get_events(state.id, 1) |> get_payload()
    end

    test "then process version should be 1", state do
      assert get_process_version(state.pid) == 1
    end

    test "then process should be in initial behavior", state do
      assert get_current_behavior(state.pid) == Eventize.BehaviorTestProcess.InitialBehavior
    end
  end

  describe "When casting process to enter initial from secondary" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id, [{:seconday_behavior_entered, %{}}])

      GenServer.cast(pid, :enter_initial)

      :pong = GenServer.call(pid, :ping)

      {:ok, pid: pid, id: id}
    end

    test "then one event should be stored", state do
      assert length(get_events(state.id, 1)) == 1
    end

    test "then a :initial_behavior_entered event should be stored", state do
      assert [{:initial_behavior_entered, _}] = get_events(state.id, 1) |> get_payload()
    end

    test "then process version should be 1", state do
      assert get_process_version(state.pid) == 1
    end

    test "then process should be in initial behavior", state do
      assert get_current_behavior(state.pid) == Eventize.BehaviorTestProcess.InitialBehavior
    end
  end

  describe "When calling process to enter initial from initial" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id)

      response = GenServer.call(pid, :enter_initial)

      {:ok, pid: pid, id: id, response: response}
    end

    test "then response should be :error", state do
      assert state.response == {:error, "Already in initial"}
    end

    test "then no events should be stored", state do
      assert get_events(state.id) == []
    end

    test "then process version should be :empty", state do
      assert get_process_version(state.pid) == :empty
    end

    test "then process should be in initial behavior", state do
      assert get_current_behavior(state.pid) == Eventize.BehaviorTestProcess.InitialBehavior
    end
  end

  describe "When casting process to enter initial from initial" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id)

      GenServer.cast(pid, :enter_initial)

      :pong = GenServer.call(pid, :ping)

      {:ok, pid: pid, id: id}
    end

    test "then no events should be stored", state do
      assert get_events(state.id) == []
    end

    test "then process version should be :empty", state do
      assert get_process_version(state.pid) == :empty
    end

    test "then process should be in initial behavior", state do
      assert get_current_behavior(state.pid) == Eventize.BehaviorTestProcess.InitialBehavior
    end
  end

  describe "When calling process to enter secondary from secondary" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id, [{:seconday_behavior_entered, %{}}])

      response = GenServer.call(pid, :enter_secondary)

      {:ok, pid: pid, id: id, response: response}
    end

    test "then response should be :error", state do
      assert state.response == {:error, "Already in secondary"}
    end

    test "then no event should be stored", state do
      assert get_events(state.id, 1) == []
    end

    test "then process version should be 0", state do
      assert get_process_version(state.pid) == 0
    end

    test "then process should be in secondary behavior", state do
      assert get_current_behavior(state.pid) == Eventize.BehaviorTestProcess.SecondaryBehavior
    end
  end

  describe "When casting process to enter secondary from secondary" do
    setup do
      id = UUID.uuid4()

      pid = get_process(id, [{:seconday_behavior_entered, %{}}])

      GenServer.cast(pid, :enter_secondary)

      :pong = GenServer.call(pid, :ping)

      {:ok, pid: pid, id: id}
    end

    test "then no event should be stored", state do
      assert get_events(state.id, 1) == []
    end

    test "then process version should be 0", state do
      assert get_process_version(state.pid) == 0
    end

    test "then process should be in secondary behavior", state do
      assert get_current_behavior(state.pid) == Eventize.BehaviorTestProcess.SecondaryBehavior
    end
  end
end
