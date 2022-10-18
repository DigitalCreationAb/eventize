defmodule InMemoryEventStoreTest do
  use ExUnit.Case

  alias Reactive.Persistence.InMemoryEventStore
  alias Reactive.Persistence.EventStore
  doctest InMemoryEventStore

  test "Can store single event" do
    EventStore.append_events("test", [%{title: "title"}])
    
    events = EventStore.load_events("test")
    
    assert length(events) == 1
  end
end
