defmodule EntityTest do
  use ExUnit.Case
  doctest Reactive.Entities.Entity
  
  describe "When asking entity with behavior" do
    setup do
      entity_id = UUID.uuid4()
      
      response = TestCommandBus.call(TestEntityWithBehavior, entity_id, %TestEntityWithBehavior.Commands.Start{title: "test"})
      
      {:ok, id: entity_id, response: response}
    end
    
    test "then response has correct title", state do
      assert state.response.title == "test"
    end
    
    test "then state has correct title", state do
      entity_state = :sys.get_state({:global, "#{TestEntityWithBehavior}-#{state.id}"})

      assert entity_state.state.title == "test"
    end
  end
  
  describe "When sending to entity with behavior" do
    setup do
      entity_id = UUID.uuid4()

      TestCommandBus.cast(TestEntityWithBehavior, entity_id, %TestEntityWithBehavior.Commands.Start{title: "test"})

      {:ok, id: entity_id}
    end

    test "then state has correct title", state do
      entity_state = :sys.get_state({:global, "#{TestEntityWithBehavior}-#{state.id}"})

      assert entity_state.state.title == "test"
    end
  end
  
  describe "When sending same command with different behaviors" do
    setup do
      entity_id = UUID.uuid4()

      TestCommandBus.cast(TestEntityWithBehavior, entity_id, %TestEntityWithBehavior.Commands.Start{title: "test1"})

      TestCommandBus.cast(TestEntityWithBehavior, entity_id, %TestEntityWithBehavior.Commands.Start{title: "test2"})

      {:ok, id: entity_id}
    end

    test "then state has correct title", state do
      entity_state = :sys.get_state({:global, "#{TestEntityWithBehavior}-#{state.id}"})

      assert entity_state.state.title == "test1"
    end

    test "then state has correct second title", state do
      entity_state = :sys.get_state({:global, "#{TestEntityWithBehavior}-#{state.id}"})

      assert entity_state.state.secondTitle == "test2"
    end
  end

  describe "When asking entity without behavior" do
    setup do
      entity_id = UUID.uuid4()

      response = TestCommandBus.call(TestEntityWithoutBehavior, entity_id, %TestEntityWithoutBehavior.Commands.Start{title: "test"})

      {:ok, id: entity_id, response: response}
    end

    test "then response has correct title", state do
      assert state.response.title == "test"
    end

    test "then state has correct title", state do
      entity_state = :sys.get_state({:global, "#{TestEntityWithoutBehavior}-#{state.id}"})

      assert entity_state.state.title == "test"
    end
  end

  describe "When sending to entity without behavior" do
    setup do
      entity_id = UUID.uuid4()

      TestCommandBus.cast(TestEntityWithoutBehavior, entity_id, %TestEntityWithoutBehavior.Commands.Start{title: "test"})

      {:ok, id: entity_id}
    end

    test "then state has correct title", state do
      entity_state = :sys.get_state({:global, "#{TestEntityWithoutBehavior}-#{state.id}"})

      assert entity_state.state.title == "test"
    end
  end
  
  describe "When sending command that results in event that stops entity" do
    setup do
      entity_id = UUID.uuid4()

      pid = TestEntitiesSupervisor.get_entity(TestEntityWithoutBehavior, entity_id)

      ref = Process.monitor(pid)

      %{id: entity_id, ref: ref}
    end
    
    test "then entity should be stopped", %{ref: ref, id: id} do
      TestCommandBus.cast(TestEntityWithoutBehavior, id, %TestEntityWithoutBehavior.Commands.Stop{id: "test"})
      
      assert_receive {:DOWN, ^ref, :process, _pid, :normal}
    end
  end
end
