defmodule InMemoryEventStoreTest do
  use Eventize.EventStore.EventStoreTestCase, event_store: Eventize.Persistence.InMemoryEventStore
end
