defmodule InMemoryEventStoreTest do
  use ExUnit.Case

  alias Reactive.Persistence.InMemoryEventStore
  alias Reactive.Persistence.EventStore
  doctest InMemoryEventStore
  
  describe "When storing single event" do
    setup do
      stream_name = UUID.uuid4()

      EventStore.append_events(stream_name, [%{title: "title"}])

      {:ok, stream_name: stream_name}
    end
    
    test "then one event can be loaded", state do
      events = EventStore.load_events(state.stream_name)

      assert length(events) == 1
    end
    
    test "then event should have correct title", state do
      [first] = EventStore.load_events(state.stream_name)
      
      assert first.title == "title"
    end
  end

  describe "When storing two events" do
    setup do
      stream_name = UUID.uuid4()

      EventStore.append_events(stream_name, [%{title: "title1"}, %{title: "title2"}])

      {:ok, stream_name: stream_name}
    end

    test "then two event can be loaded", state do
      events = EventStore.load_events(state.stream_name)

      assert length(events) == 2
    end

    test "then first event should have correct title", state do
      [first, _] = EventStore.load_events(state.stream_name)

      assert first.title == "title1"
    end

    test "then second event should have correct title", state do
      [_, second] = EventStore.load_events(state.stream_name)

      assert second.title == "title2"
    end
  end

  describe "When storing two events in two transactions" do
    setup do
      stream_name = UUID.uuid4()

      EventStore.append_events(stream_name, [%{title: "title1"}])
      EventStore.append_events(stream_name, [%{title: "title2"}])

      {:ok, stream_name: stream_name}
    end

    test "then two event can be loaded", state do
      events = EventStore.load_events(state.stream_name)

      assert length(events) == 2
    end

    test "then first event should have correct title", state do
      [first, _] = EventStore.load_events(state.stream_name)

      assert first.title == "title1"
    end

    test "then second event should have correct title", state do
      [_, second] = EventStore.load_events(state.stream_name)

      assert second.title == "title2"
    end
  end
end
