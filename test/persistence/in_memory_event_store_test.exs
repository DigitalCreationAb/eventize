defmodule InMemoryEventStoreTest do
  use ExUnit.Case

  alias Reactive.Persistence.InMemoryEventStore
  alias Reactive.Persistence.EventBus.EventData
  doctest InMemoryEventStore

  describe "When storing single tuple event" do
    setup do
      stream_name = UUID.uuid4()

      TestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title"}}, %{}}])

      {:ok, stream_name: stream_name}
    end

    test "then one event can be loaded", state do
      {:ok, _version, events} = TestEventBus.load_events(state.stream_name)

      assert length(events) == 1
    end

    test "then version 1 is returned when loading", state do
      {:ok, version, _events} = TestEventBus.load_events(state.stream_name)

      assert version == 1
    end

    test "then event should have correct title", state do
      {:ok, _version, [%EventData{payload: {:title_updated, first}}]} =
        TestEventBus.load_events(state.stream_name)

      assert first.title == "title"
    end

    test "then event should have correct sequence number", state do
      {:ok, _version, [%EventData{sequence_number: sequence_number}]} =
        TestEventBus.load_events(state.stream_name)

      assert sequence_number == 1
    end
  end

  describe "When storing two tuple events" do
    setup do
      stream_name = UUID.uuid4()

      TestEventBus.append_events(stream_name, [
        {{:title_updated, %{title: "title1"}}, %{}},
        {{:title_updated, %{title: "title2"}}, %{}}
      ])

      {:ok, stream_name: stream_name}
    end

    test "then two event can be loaded", state do
      {:ok, _version, events} = TestEventBus.load_events(state.stream_name)

      assert length(events) == 2
    end

    test "then version 2 is returned when loading", state do
      {:ok, version, _events} = TestEventBus.load_events(state.stream_name)

      assert version == 2
    end

    test "then first event should have correct title", state do
      {:ok, _version, [%EventData{payload: {:title_updated, first}}, _]} =
        TestEventBus.load_events(state.stream_name)

      assert first.title == "title1"
    end

    test "then second event should have correct title", state do
      {:ok, _version, [_, %EventData{payload: {:title_updated, second}}]} =
        TestEventBus.load_events(state.stream_name)

      assert second.title == "title2"
    end

    test "then first event should have correct sequence number", state do
      {:ok, _version, [%EventData{sequence_number: sequence_number}, _]} =
        TestEventBus.load_events(state.stream_name)

      assert sequence_number == 1
    end

    test "then second event should have correct sequence number", state do
      {:ok, _version, [_, %EventData{sequence_number: sequence_number}]} =
        TestEventBus.load_events(state.stream_name)

      assert sequence_number == 2
    end
  end

  describe "When storing two tuple events in two transactions" do
    setup do
      stream_name = UUID.uuid4()

      TestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title1"}}, %{}}])
      TestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title2"}}, %{}}])

      {:ok, stream_name: stream_name}
    end

    test "then two event can be loaded", state do
      {:ok, _version, events} = TestEventBus.load_events(state.stream_name)

      assert length(events) == 2
    end

    test "then version 2 is returned when loading", state do
      {:ok, version, _events} = TestEventBus.load_events(state.stream_name)

      assert version == 2
    end

    test "then first event should have correct title", state do
      {:ok, _version, [%EventData{payload: {:title_updated, first}}, _]} =
        TestEventBus.load_events(state.stream_name)

      assert first.title == "title1"
    end

    test "then second event should have correct title", state do
      {:ok, _version, [_, %EventData{payload: {:title_updated, second}}]} =
        TestEventBus.load_events(state.stream_name)

      assert second.title == "title2"
    end

    test "then first event should have correct sequence number", state do
      {:ok, _version, [%EventData{sequence_number: sequence_number}, _]} =
        TestEventBus.load_events(state.stream_name)

      assert sequence_number == 1
    end

    test "then second event should have correct sequence number", state do
      {:ok, _version, [_, %EventData{sequence_number: sequence_number}]} =
        TestEventBus.load_events(state.stream_name)

      assert sequence_number == 2
    end
  end

  describe "When storing single struct event" do
    setup do
      stream_name = UUID.uuid4()

      TestEventBus.append_events(stream_name, [{%TitleUpdated{title: "title"}, %{}}])

      {:ok, stream_name: stream_name}
    end

    test "then one event can be loaded", state do
      {:ok, _version, events} = TestEventBus.load_events(state.stream_name)

      assert length(events) == 1
    end

    test "then version 1 is returned when loading", state do
      {:ok, version, _events} = TestEventBus.load_events(state.stream_name)

      assert version == 1
    end

    test "then event should have correct title", state do
      {:ok, _version, [%EventData{payload: %TitleUpdated{} = first}]} =
        TestEventBus.load_events(state.stream_name)

      assert first.title == "title"
    end

    test "then event should have correct sequence number", state do
      {:ok, _version, [%EventData{sequence_number: sequence_number}]} =
        TestEventBus.load_events(state.stream_name)

      assert sequence_number == 1
    end
  end

  describe "When storing two struct events" do
    setup do
      stream_name = UUID.uuid4()

      TestEventBus.append_events(stream_name, [
        {%TitleUpdated{title: "title1"}, %{}},
        {%TitleUpdated{title: "title2"}, %{}}
      ])

      {:ok, stream_name: stream_name}
    end

    test "then two event can be loaded", state do
      {:ok, _version, events} = TestEventBus.load_events(state.stream_name)

      assert length(events) == 2
    end

    test "then version 2 is returned when loading", state do
      {:ok, version, _events} = TestEventBus.load_events(state.stream_name)

      assert version == 2
    end

    test "then first event should have correct title", state do
      {:ok, _version, [%EventData{payload: %TitleUpdated{} = first}, _]} =
        TestEventBus.load_events(state.stream_name)

      assert first.title == "title1"
    end

    test "then second event should have correct title", state do
      {:ok, _version, [_, %EventData{payload: %TitleUpdated{} = second}]} =
        TestEventBus.load_events(state.stream_name)

      assert second.title == "title2"
    end

    test "then first event should have correct sequence number", state do
      {:ok, _version, [%EventData{sequence_number: sequence_number}, _]} =
        TestEventBus.load_events(state.stream_name)

      assert sequence_number == 1
    end

    test "then second event should have correct sequence number", state do
      {:ok, _version, [_, %EventData{sequence_number: sequence_number}]} =
        TestEventBus.load_events(state.stream_name)

      assert sequence_number == 2
    end
  end

  describe "When storing two struct events in two transactions" do
    setup do
      stream_name = UUID.uuid4()

      TestEventBus.append_events(stream_name, [{%TitleUpdated{title: "title1"}, %{}}])
      TestEventBus.append_events(stream_name, [{%TitleUpdated{title: "title2"}, %{}}])

      {:ok, stream_name: stream_name}
    end

    test "then two event can be loaded", state do
      {:ok, _version, events} = TestEventBus.load_events(state.stream_name)

      assert length(events) == 2
    end

    test "then version 2 is returned when loading", state do
      {:ok, version, _events} = TestEventBus.load_events(state.stream_name)

      assert version == 2
    end

    test "then first event should have correct title", state do
      {:ok, _version, [%EventData{payload: %TitleUpdated{} = first}, _]} =
        TestEventBus.load_events(state.stream_name)

      assert first.title == "title1"
    end

    test "then second event should have correct title", state do
      {:ok, _version, [_, %EventData{payload: %TitleUpdated{} = second}]} =
        TestEventBus.load_events(state.stream_name)

      assert second.title == "title2"
    end

    test "then first event should have correct sequence number", state do
      {:ok, _version, [%EventData{sequence_number: sequence_number}, _]} =
        TestEventBus.load_events(state.stream_name)

      assert sequence_number == 1
    end

    test "then second event should have correct sequence number", state do
      {:ok, _version, [_, %EventData{sequence_number: sequence_number}]} =
        TestEventBus.load_events(state.stream_name)

      assert sequence_number == 2
    end
  end

  describe "When storing two events with expected version 0" do
    setup do
      stream_name = UUID.uuid4()

      first_response =
        TestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title1"}}, %{}}], 0)

      second_response =
        TestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title2"}}, %{}}], 0)

      {:ok,
       stream_name: stream_name, first_response: first_response, second_response: second_response}
    end

    test "then one event can be loaded", state do
      {:ok, _version, events} = TestEventBus.load_events(state.stream_name)

      assert length(events) == 1
    end

    test "then version 1 is returned when loading", state do
      {:ok, version, _events} = TestEventBus.load_events(state.stream_name)

      assert version == 1
    end

    test "then first response is ok", state do
      assert {:ok, 1} = state.first_response
    end

    test "then second response is error", state do
      assert {:error, {:expected_version_missmatch, %{current_version: 1, expected_version: 0}}} =
               state.second_response
    end
  end

  describe "When storing two events with correct expected version" do
    setup do
      stream_name = UUID.uuid4()

      first_response =
        TestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title1"}}, %{}}], 0)

      second_response =
        TestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title2"}}, %{}}], 1)

      {:ok,
       stream_name: stream_name, first_response: first_response, second_response: second_response}
    end

    test "then two event can be loaded", state do
      {:ok, _version, events} = TestEventBus.load_events(state.stream_name)

      assert length(events) == 2
    end

    test "then version 2 is returned when loading", state do
      {:ok, version, _events} = TestEventBus.load_events(state.stream_name)

      assert version == 2
    end

    test "then first response is ok", state do
      assert {:ok, 1} = state.first_response
    end

    test "then second response is ok", state do
      assert {:ok, 2} = state.second_response
    end
  end

  describe "When storing two events and loading from start with max_count 1" do
    setup do
      stream_name = UUID.uuid4()

      TestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title1"}}, %{}}], 0)
      TestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title2"}}, %{}}], 1)

      response = TestEventBus.load_events(stream_name, :start, 1)

      {:ok, response: response}
    end

    test "then one event is loaded", state do
      {:ok, _version, events} = state.response

      assert length(events) == 1
    end

    test "then version 2 is returned when loading", state do
      {:ok, version, _events} = state.response

      assert version == 2
    end

    test "then event should have correct title", state do
      {:ok, _version, [%EventData{payload: {:title_updated, first}}]} = state.response

      assert first.title == "title1"
    end

    test "then event should have correct sequence number", state do
      {:ok, _version, [%EventData{sequence_number: sequence_number}]} = state.response

      assert sequence_number == 1
    end
  end

  describe "When storing two events and loading from 2 with max_count 1" do
    setup do
      stream_name = UUID.uuid4()

      TestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title1"}}, %{}}], 0)
      TestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title2"}}, %{}}], 1)

      response = TestEventBus.load_events(stream_name, 2, 1)

      {:ok, response: response}
    end

    test "then one event is loaded", state do
      {:ok, _version, events} = state.response

      assert length(events) == 1
    end

    test "then version 2 is returned when loading", state do
      {:ok, version, _events} = state.response

      assert version == 2
    end

    test "then event should have correct title", state do
      {:ok, _version, [%EventData{payload: {:title_updated, first}}]} = state.response

      assert first.title == "title2"
    end

    test "then event should have correct sequence number", state do
      {:ok, _version, [%EventData{sequence_number: sequence_number}]} = state.response

      assert sequence_number == 2
    end
  end
end
