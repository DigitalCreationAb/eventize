defmodule InMemoryEventStoreTest do
  use EventStoreTests, Reactive.Persistence.InMemoryEventStore
end
