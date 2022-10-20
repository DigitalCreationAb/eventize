defmodule PersistedEntityTest do
  use ExUnit.Case
  doctest Reactive.Entities.PersistedEntity

  describe "When starting entity then stopping before getting the state" do
    setup do
      entity_id = UUID.uuid4()

      Reactive.ask(TestPersistedEntityWithoutBehavior, entity_id, %TestPersistedEntityWithoutBehavior.Commands.Start{title: "test"})

      pid = Reactive.Entities.Supervisor.get_entity(TestPersistedEntityWithoutBehavior, entity_id)

      GenServer.stop(pid)
      
      response = Reactive.ask(TestPersistedEntityWithoutBehavior, entity_id, %TestPersistedEntityWithoutBehavior.Commands.GetTitle{})
      
      {:ok, id: entity_id, response: response}
    end
    
    test "then response should have correct title", state do
      assert state.response.title == "test"
    end
  end

  describe "When starting entity then getting the state" do
    setup do
      entity_id = UUID.uuid4()

      Reactive.ask(TestPersistedEntityWithoutBehavior, entity_id, %TestPersistedEntityWithoutBehavior.Commands.Start{title: "test"})

      response = Reactive.ask(TestPersistedEntityWithoutBehavior, entity_id, %TestPersistedEntityWithoutBehavior.Commands.GetTitle{})

      {:ok, id: entity_id, response: response}
    end

    test "then response should have correct title", state do
      assert state.response.title == "test"
    end
  end
end
