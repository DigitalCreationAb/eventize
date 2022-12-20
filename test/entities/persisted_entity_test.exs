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

  describe "When starting entity and deleting previous events" do
    setup do
      entity_id = UUID.uuid4()

      TestCommandBus.call(
        TestPersistedEntityWithoutBehavior,
        entity_id,
        {:start, %{title: "test"}}
      )

      TestCommandBus.call(
        TestPersistedEntityWithoutBehavior,
        entity_id,
        :delete_previous
      )

      {:ok, stored_version, stored_events} =
        GenServer.call(
          Reactive.Persistence.EventStore,
          {:load_events,
           %{
             stream_name: "testpersistedentitywithoutbehavior-#{entity_id}",
             start: :start,
             max_count: :all
           }}
        )

      {:ok, id: entity_id, stored_version: stored_version, stored_events: stored_events}
    end

    test "then one event should be in store for entity", state do
      assert length(state.stored_events) == 1
    end

    test "then stored version is 2", state do
      assert state.stored_version == 2
    end
  end
end
