defmodule EntityTest do
  use ExUnit.Case
  doctest Eventize.Entities.Entity

  describe "When calling entity with behavior" do
    setup do
      entity_id = UUID.uuid4()

      {:ok, pid} = TestEntityWithBehavior.start_link(entity_id)

      response = GenServer.call(pid, {:execute, {:start, %{title: "test"}}})

      {:ok, pid: pid, response: response}
    end

    test "then response has correct title", state do
      assert state.response.title == "test"
    end

    test "then state has correct title", state do
      entity_state = :sys.get_state(state.pid)

      assert entity_state.state.title == "test"
    end
  end

  describe "When casting to entity with behavior" do
    setup do
      entity_id = UUID.uuid4()

      {:ok, pid} = TestEntityWithBehavior.start_link(entity_id)

      GenServer.cast(pid, {:execute, {:start, %{title: "test"}}})

      {:ok, pid: pid}
    end

    test "then state has correct title", state do
      entity_state = :sys.get_state(state.pid)

      assert entity_state.state.title == "test"
    end
  end

  describe "When casting same command with different behaviors" do
    setup do
      entity_id = UUID.uuid4()

      {:ok, pid} = TestEntityWithBehavior.start_link(entity_id)

      GenServer.cast(pid, {:execute, {:start, %{title: "test1"}}})

      GenServer.cast(pid, {:execute, {:start, %{title: "test2"}}})

      {:ok, pid: pid}
    end

    test "then state has correct title", state do
      entity_state = :sys.get_state(state.pid)

      assert entity_state.state.title == "test1"
    end

    test "then state has correct second title", state do
      entity_state = :sys.get_state(state.pid)

      assert entity_state.state.secondTitle == "test2"
    end
  end

  describe "When calling entity without behavior" do
    setup do
      entity_id = UUID.uuid4()

      {:ok, pid} = TestEntityWithoutBehavior.start_link(entity_id)

      response = GenServer.call(pid, {:execute, {:start, %{title: "test"}}})

      {:ok, pid: pid, response: response}
    end

    test "then response has correct title", state do
      assert state.response.title == "test"
    end

    test "then state has correct title", state do
      entity_state = :sys.get_state(state.pid)

      assert entity_state.state.title == "test"
    end
  end

  describe "When casting to entity without behavior" do
    setup do
      entity_id = UUID.uuid4()

      {:ok, pid} = TestEntityWithoutBehavior.start_link(entity_id)

      GenServer.cast(pid, {:execute, {:start, %{title: "test"}}})

      {:ok, pid: pid}
    end

    test "then state has correct title", state do
      entity_state = :sys.get_state(state.pid)

      assert entity_state.state.title == "test"
    end
  end

  describe "When casting command that results in event that stops entity" do
    setup do
      entity_id = UUID.uuid4()

      {:ok, pid} = TestEntityWithoutBehavior.start_link(entity_id)

      ref = Process.monitor(pid)

      %{pid: pid, ref: ref}
    end

    test "then entity should be stopped", %{ref: ref, pid: pid} do
      GenServer.cast(pid, {:execute, :stop})

      assert_receive {:DOWN, ^ref, :process, _pid, :normal}
    end
  end

  describe "When calling entity and supplying message_id and correlation_id" do
    setup do
      entity_id = UUID.uuid4()

      {:ok, pid} = TestEntityWithBehavior.start_link(entity_id)

      response =
        GenServer.call(
          pid,
          {:execute, {:start, %{title: "test"}},
           %{message_id: UUID.uuid4(), correlation_id: UUID.uuid4()}}
        )

      {:ok, pid: pid, response: response}
    end

    test "then response has correct title", state do
      assert state.response.title == "test"
    end

    test "then state has correct title", state do
      entity_state = :sys.get_state(state.pid)

      assert entity_state.state.title == "test"
    end
  end

  describe "When calling entity and supplying message_id" do
    setup do
      entity_id = UUID.uuid4()

      {:ok, pid} = TestEntityWithBehavior.start_link(entity_id)

      response =
        GenServer.call(
          pid,
          {:execute, {:start, %{title: "test"}}, %{message_id: UUID.uuid4()}}
        )

      {:ok, pid: pid, response: response}
    end

    test "then response has correct title", state do
      assert state.response.title == "test"
    end

    test "then state has correct title", state do
      entity_state = :sys.get_state(state.pid)

      assert entity_state.state.title == "test"
    end
  end

  describe "When calling entity and supplying correlation_id" do
    setup do
      entity_id = UUID.uuid4()

      {:ok, pid} = TestEntityWithBehavior.start_link(entity_id)

      response =
        GenServer.call(
          pid,
          {:execute, {:start, %{title: "test"}}, %{correlation_id: UUID.uuid4()}}
        )

      {:ok, pid: pid, response: response}
    end

    test "then response has correct title", state do
      assert state.response.title == "test"
    end

    test "then state has correct title", state do
      entity_state = :sys.get_state(state.pid)

      assert entity_state.state.title == "test"
    end
  end

  describe "When casting to entity and supplying message_id and correlation_id" do
    setup do
      entity_id = UUID.uuid4()

      {:ok, pid} = TestEntityWithBehavior.start_link(entity_id)

      GenServer.cast(
        pid,
        {:execute, {:start, %{title: "test"}},
         %{message_id: UUID.uuid4(), correlation_id: UUID.uuid4()}}
      )

      {:ok, pid: pid}
    end

    test "then state has correct title", state do
      entity_state = :sys.get_state(state.pid)

      assert entity_state.state.title == "test"
    end
  end

  describe "When casting to entity and supplying message_id" do
    setup do
      entity_id = UUID.uuid4()

      {:ok, pid} = TestEntityWithBehavior.start_link(entity_id)

      GenServer.cast(
        pid,
        {:execute, {:start, %{title: "test"}}, %{message_id: UUID.uuid4()}}
      )

      {:ok, pid: pid}
    end

    test "then state has correct title", state do
      entity_state = :sys.get_state(state.pid)

      assert entity_state.state.title == "test"
    end
  end

  describe "When casting to entity and supplying correlation_id" do
    setup do
      entity_id = UUID.uuid4()

      {:ok, pid} = TestEntityWithBehavior.start_link(entity_id)

      GenServer.cast(
        pid,
        {:execute, {:start, %{title: "test"}}, %{correlation_id: UUID.uuid4()}}
      )

      {:ok, pid: pid}
    end

    test "then state has correct title", state do
      entity_state = :sys.get_state(state.pid)

      assert entity_state.state.title == "test"
    end
  end
end
