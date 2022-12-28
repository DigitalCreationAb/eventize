defmodule InMemoryEventStoreTest do
  use Eventize.EventStoreTests, Eventize.Persistence.InMemoryEventStore
end
