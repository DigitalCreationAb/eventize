defmodule PersistedEntityTest do
  use ExUnit.Case
  doctest Reactive.Entities.PersistedEntity

  describe "When starting entity then stopping before getting the state" do
    setup do
      entity_id = UUID.uuid4()

      TestCommandBus.call(
        TestPersistedEntityWithoutBehavior,
        entity_id,
        {:start, %{title: "test"}}
      )

      pid = TestEntitiesSupervisor.get_entity(TestPersistedEntityWithoutBehavior, entity_id)

      GenServer.stop(pid)

      response =
        TestCommandBus.call(
          TestPersistedEntityWithoutBehavior,
          entity_id,
          :get_title
        )

      {:ok, id: entity_id, response: response}
    end

    test "then response should have correct title", state do
      assert state.response.title == "test"
    end
  end

  describe "When starting entity then getting the state" do
    setup do
      entity_id = UUID.uuid4()

      TestCommandBus.call(
        TestPersistedEntityWithoutBehavior,
        entity_id,
        {:start, %{title: "test"}}
      )

      response =
        TestCommandBus.call(
          TestPersistedEntityWithoutBehavior,
          entity_id,
          :get_title
        )

      {:ok, id: entity_id, response: response}
    end

    test "then response should have correct title", state do
      assert state.response.title == "test"
    end
  end
end
