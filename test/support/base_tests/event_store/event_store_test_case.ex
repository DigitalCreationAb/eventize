defmodule Eventize.EventStore.EventStoreTestCase do
  import Eventize.SharedTestCase

  defmodule EventStoreTestEventBus do
    @moduledoc false

    def load_events(stream_name, start \\ :start, max_count \\ :all) do
      GenServer.call(
        TestEventStore,
        {:load_events,
         %{
           stream_name: stream_name,
           start: start,
           max_count: max_count
         }}
      )
    end

    def append_events(stream_name, events, expected_version \\ :any) do
      GenServer.call(
        TestEventStore,
        {:append_events,
         %{
           stream_name: stream_name,
           events: events,
           expected_version: expected_version
         }}
      )
    end

    def delete_events(stream_name, version) do
      GenServer.call(
        TestEventStore,
        {:delete_events, %{stream_name: stream_name, version: version}}
      )
    end

    def load_snapshot(stream_name, max_version \\ :max) do
      GenServer.call(
        TestEventStore,
        {:load_snapshot, %{stream_name: stream_name, max_version: max_version}}
      )
    end

    def append_snapshot(stream_name, snapshot, version) do
      GenServer.call(
        TestEventStore,
        {:append_snapshot,
         %{
           stream_name: stream_name,
           snapshot: snapshot,
           version: version
         }}
      )
    end

    def delete_snapshots(stream_name, version) do
      GenServer.call(
        TestEventStore,
        {:delete_snapshots, %{stream_name: stream_name, version: version}}
      )
    end
  end

  defmodule TestSnapshot do
    @moduledoc false

    @derive Jason.Encoder
    defstruct [:title]
  end

  defmodule TestEvent do
    @moduledoc false

    @derive Jason.Encoder
    defstruct [:title]
  end

  define_tests do
    alias Eventize.EventStore.EventStoreTestCase.TestSnapshot
    alias Eventize.EventStore.EventStoreTestCase.TestEvent
    alias Eventize.EventStore.EventStoreTestCase.EventStoreTestEventBus
    alias Eventize.Persistence.EventStore.EventData
    alias Eventize.Persistence.EventStore.SnapshotData

    setup_all do
      before_start()

      [[event_store: event_store]] = @moduletag

      start_supervised({event_store, [{:name, TestEventStore} | get_start_options()]})

      :ok
    end

    defp get_start_options() do
      []
    end

    defp before_start() do
      nil
    end

    defoverridable get_start_options: 0,
                   before_start: 0

    test "Event store should impliment EventStore behaviour" do
      [[event_store: event_store]] = @moduletag

      assert_implements(event_store, Eventize.Persistence.EventStore)
    end

    describe "When storing single tuple event" do
      setup do
        stream_name = UUID.uuid4()

        EventStoreTestEventBus.append_events(stream_name, [
          {{:title_updated, %{title: "title"}}, %{}}
        ])

        {:ok, stream_name: stream_name}
      end

      test "then one event can be loaded", state do
        {:ok, events} = EventStoreTestEventBus.load_events(state.stream_name)

        assert length(events) == 1
      end

      test "then event should have correct title", state do
        {:ok, [%EventData{payload: {:title_updated, first}}]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert first.title == "title"
      end

      test "then event should have correct sequence number", state do
        {:ok, [%EventData{sequence_number: sequence_number}]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert sequence_number == 0
      end
    end

    describe "When storing two tuple events" do
      setup do
        stream_name = UUID.uuid4()

        EventStoreTestEventBus.append_events(stream_name, [
          {{:title_updated, %{title: "title1"}}, %{}},
          {{:title_updated, %{title: "title2"}}, %{}}
        ])

        {:ok, stream_name: stream_name}
      end

      test "then two event can be loaded", state do
        {:ok, events} = EventStoreTestEventBus.load_events(state.stream_name)

        assert length(events) == 2
      end

      test "then first event should have correct title", state do
        {:ok, [%EventData{payload: {:title_updated, first}}, _]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert first.title == "title1"
      end

      test "then second event should have correct title", state do
        {:ok, [_, %EventData{payload: {:title_updated, second}}]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert second.title == "title2"
      end

      test "then first event should have correct sequence number", state do
        {:ok, [%EventData{sequence_number: sequence_number}, _]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert sequence_number == 0
      end

      test "then second event should have correct sequence number", state do
        {:ok, [_, %EventData{sequence_number: sequence_number}]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert sequence_number == 1
      end
    end

    describe "When storing two tuple events in two transactions" do
      setup do
        stream_name = UUID.uuid4()

        EventStoreTestEventBus.append_events(stream_name, [
          {{:title_updated, %{title: "title1"}}, %{}}
        ])

        EventStoreTestEventBus.append_events(stream_name, [
          {{:title_updated, %{title: "title2"}}, %{}}
        ])

        {:ok, stream_name: stream_name}
      end

      test "then two event can be loaded", state do
        {:ok, events} = EventStoreTestEventBus.load_events(state.stream_name)

        assert length(events) == 2
      end

      test "then first event should have correct title", state do
        {:ok, [%EventData{payload: {:title_updated, first}}, _]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert first.title == "title1"
      end

      test "then second event should have correct title", state do
        {:ok, [_, %EventData{payload: {:title_updated, second}}]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert second.title == "title2"
      end

      test "then first event should have correct sequence number", state do
        {:ok, [%EventData{sequence_number: sequence_number}, _]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert sequence_number == 0
      end

      test "then second event should have correct sequence number", state do
        {:ok, [_, %EventData{sequence_number: sequence_number}]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert sequence_number == 1
      end
    end

    describe "When storing single struct event" do
      setup do
        stream_name = UUID.uuid4()

        EventStoreTestEventBus.append_events(stream_name, [{%TestEvent{title: "title"}, %{}}])

        {:ok, stream_name: stream_name}
      end

      test "then one event can be loaded", state do
        {:ok, events} = EventStoreTestEventBus.load_events(state.stream_name)

        assert length(events) == 1
      end

      test "then event should have correct title", state do
        {:ok, [%EventData{payload: %TestEvent{} = first}]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert first.title == "title"
      end

      test "then event should have correct sequence number", state do
        {:ok, [%EventData{sequence_number: sequence_number}]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert sequence_number == 0
      end
    end

    describe "When storing two struct events" do
      setup do
        stream_name = UUID.uuid4()

        EventStoreTestEventBus.append_events(stream_name, [
          {%TestEvent{title: "title1"}, %{}},
          {%TestEvent{title: "title2"}, %{}}
        ])

        {:ok, stream_name: stream_name}
      end

      test "then two event can be loaded", state do
        {:ok, events} = EventStoreTestEventBus.load_events(state.stream_name)

        assert length(events) == 2
      end

      test "then first event should have correct title", state do
        {:ok, [%EventData{payload: %TestEvent{} = first}, _]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert first.title == "title1"
      end

      test "then second event should have correct title", state do
        {:ok, [_, %EventData{payload: %TestEvent{} = second}]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert second.title == "title2"
      end

      test "then first event should have correct sequence number", state do
        {:ok, [%EventData{sequence_number: sequence_number}, _]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert sequence_number == 0
      end

      test "then second event should have correct sequence number", state do
        {:ok, [_, %EventData{sequence_number: sequence_number}]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert sequence_number == 1
      end
    end

    describe "When storing two struct events in two transactions" do
      setup do
        stream_name = UUID.uuid4()

        EventStoreTestEventBus.append_events(stream_name, [
          {%TestEvent{title: "title1"}, %{}}
        ])

        EventStoreTestEventBus.append_events(stream_name, [
          {%TestEvent{title: "title2"}, %{}}
        ])

        {:ok, stream_name: stream_name}
      end

      test "then two event can be loaded", state do
        {:ok, events} = EventStoreTestEventBus.load_events(state.stream_name)

        assert length(events) == 2
      end

      test "then first event should have correct title", state do
        {:ok, [%EventData{payload: %TestEvent{} = first}, _]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert first.title == "title1"
      end

      test "then second event should have correct title", state do
        {:ok, [_, %EventData{payload: %TestEvent{} = second}]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert second.title == "title2"
      end

      test "then first event should have correct sequence number", state do
        {:ok, [%EventData{sequence_number: sequence_number}, _]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert sequence_number == 0
      end

      test "then second event should have correct sequence number", state do
        {:ok, [_, %EventData{sequence_number: sequence_number}]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert sequence_number == 1
      end
    end

    describe "When storing two events with expected version :empty" do
      setup do
        stream_name = UUID.uuid4()

        first_response =
          EventStoreTestEventBus.append_events(
            stream_name,
            [{{:title_updated, %{title: "title1"}}, %{}}],
            :empty
          )

        second_response =
          EventStoreTestEventBus.append_events(
            stream_name,
            [{{:title_updated, %{title: "title2"}}, %{}}],
            :empty
          )

        {:ok,
         stream_name: stream_name,
         first_response: first_response,
         second_response: second_response}
      end

      test "then one event can be loaded", state do
        {:ok, events} = EventStoreTestEventBus.load_events(state.stream_name)

        assert length(events) == 1
      end

      test "then first response is ok", state do
        assert {:ok, _} = state.first_response
      end

      test "then second response is error", state do
        assert {:error,
                {:expected_version_missmatch, %{current_version: 0, expected_version: :empty}}} =
                 state.second_response
      end
    end

    describe "When storing two events with correct expected version" do
      setup do
        stream_name = UUID.uuid4()

        first_response =
          EventStoreTestEventBus.append_events(
            stream_name,
            [{{:title_updated, %{title: "title1"}}, %{}}],
            :empty
          )

        second_response =
          EventStoreTestEventBus.append_events(
            stream_name,
            [{{:title_updated, %{title: "title2"}}, %{}}],
            0
          )

        {:ok,
         stream_name: stream_name,
         first_response: first_response,
         second_response: second_response}
      end

      test "then two event can be loaded", state do
        {:ok, events} = EventStoreTestEventBus.load_events(state.stream_name)

        assert length(events) == 2
      end

      test "then first response is ok", state do
        assert {:ok, _} = state.first_response
      end

      test "then second response is ok", state do
        assert {:ok, _} = state.second_response
      end
    end

    describe "When storing two events and loading from start with max_count 1" do
      setup do
        stream_name = UUID.uuid4()

        EventStoreTestEventBus.append_events(
          stream_name,
          [{{:title_updated, %{title: "title1"}}, %{}}],
          :empty
        )

        EventStoreTestEventBus.append_events(
          stream_name,
          [{{:title_updated, %{title: "title2"}}, %{}}],
          0
        )

        response = EventStoreTestEventBus.load_events(stream_name, :start, 1)

        {:ok, response: response}
      end

      test "then one event is loaded", state do
        {:ok, events} = state.response

        assert length(events) == 1
      end

      test "then event should have correct title", state do
        {:ok, [%EventData{payload: {:title_updated, first}}]} = state.response

        assert first.title == "title1"
      end

      test "then event should have correct sequence number", state do
        {:ok, [%EventData{sequence_number: sequence_number}]} = state.response

        assert sequence_number == 0
      end
    end

    describe "When storing two events and loading from 1 with max_count 1" do
      setup do
        stream_name = UUID.uuid4()

        EventStoreTestEventBus.append_events(
          stream_name,
          [{{:title_updated, %{title: "title1"}}, %{}}],
          :empty
        )

        EventStoreTestEventBus.append_events(
          stream_name,
          [{{:title_updated, %{title: "title2"}}, %{}}],
          0
        )

        response = EventStoreTestEventBus.load_events(stream_name, 1, 1)

        {:ok, response: response}
      end

      test "then one event is loaded", state do
        {:ok, events} = state.response

        assert length(events) == 1
      end

      test "then event should have correct title", state do
        {:ok, [%EventData{payload: {:title_updated, first}}]} = state.response

        assert first.title == "title2"
      end

      test "then event should have correct sequence number", state do
        {:ok, [%EventData{sequence_number: sequence_number}]} = state.response

        assert sequence_number == 1
      end
    end

    describe "When storing two events and deleting version 0" do
      setup do
        stream_name = UUID.uuid4()

        EventStoreTestEventBus.append_events(
          stream_name,
          [{{:title_updated, %{title: "title1"}}, %{}}],
          :empty
        )

        EventStoreTestEventBus.append_events(
          stream_name,
          [{{:title_updated, %{title: "title2"}}, %{}}],
          0
        )

        response = EventStoreTestEventBus.delete_events(stream_name, 0)

        {:ok, stream_name: stream_name, response: response}
      end

      test "then response should be :ok", state do
        assert state.response == :ok
      end

      test "then one event can be loaded", state do
        {:ok, events} = EventStoreTestEventBus.load_events(state.stream_name)

        assert length(events) == 1
      end

      test "then event should have correct title", state do
        {:ok, [%EventData{payload: {:title_updated, first}}]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert first.title == "title2"
      end

      test "then event should have correct sequence number", state do
        {:ok, [%EventData{sequence_number: sequence_number}]} =
          EventStoreTestEventBus.load_events(state.stream_name)

        assert sequence_number == 1
      end
    end

    describe "When storing tuple snapshot" do
      setup do
        stream_name = UUID.uuid4()

        EventStoreTestEventBus.append_snapshot(
          stream_name,
          {{:test_snapshot, %{title: "title"}}, %{}},
          1
        )

        {:ok, stream_name: stream_name}
      end

      test "then snapshot can be loaded", state do
        assert {:ok, %SnapshotData{payload: _, meta_data: _, version: _}} =
                 EventStoreTestEventBus.load_snapshot(state.stream_name)
      end

      test "then version 1 is returned when loading", state do
        {:ok, %SnapshotData{payload: _, meta_data: _, version: version}} =
          EventStoreTestEventBus.load_snapshot(state.stream_name)

        assert version == 1
      end

      test "then snapshot should have correct title", state do
        {:ok, %SnapshotData{payload: {:test_snapshot, %{title: title}}, meta_data: _, version: _}} =
          EventStoreTestEventBus.load_snapshot(state.stream_name)

        assert title == "title"
      end
    end

    describe "When storing two tuple snapshots" do
      setup do
        stream_name = UUID.uuid4()

        EventStoreTestEventBus.append_snapshot(
          stream_name,
          {{:test_snapshot, %{title: "title1"}}, %{}},
          1
        )

        EventStoreTestEventBus.append_snapshot(
          stream_name,
          {{:test_snapshot, %{title: "title2"}}, %{}},
          2
        )

        {:ok, stream_name: stream_name}
      end

      test "then latest snapshot can be loaded", state do
        assert {:ok, %SnapshotData{payload: _, meta_data: _, version: _}} =
                 EventStoreTestEventBus.load_snapshot(state.stream_name)
      end

      test "then version 2 is returned when loading", state do
        {:ok, %SnapshotData{payload: _, meta_data: _, version: version}} =
          EventStoreTestEventBus.load_snapshot(state.stream_name)

        assert version == 2
      end

      test "then snapshot should have correct title", state do
        {:ok, %SnapshotData{payload: {:test_snapshot, payload}, meta_data: _, version: _}} =
          EventStoreTestEventBus.load_snapshot(state.stream_name)

        assert payload.title == "title2"
      end

      test "then version 1 is returned when loading with max_version", state do
        {:ok, %SnapshotData{payload: _, meta_data: _, version: version}} =
          EventStoreTestEventBus.load_snapshot(state.stream_name, 1)

        assert version == 1
      end

      test "then snapshot should have correct title when loading with max_version", state do
        {:ok, %SnapshotData{payload: {:test_snapshot, payload}, meta_data: _, version: _}} =
          EventStoreTestEventBus.load_snapshot(state.stream_name, 1)

        assert payload.title == "title1"
      end
    end

    describe "When storing struct snapshot" do
      setup do
        stream_name = UUID.uuid4()

        EventStoreTestEventBus.append_snapshot(
          stream_name,
          {%TestSnapshot{title: "title"}, %{}},
          1
        )

        {:ok, stream_name: stream_name}
      end

      test "then snapshot can be loaded", state do
        assert {:ok, %SnapshotData{payload: _, meta_data: _, version: _}} =
                 EventStoreTestEventBus.load_snapshot(state.stream_name)
      end

      test "then version 1 is returned when loading", state do
        {:ok, %SnapshotData{payload: _, meta_data: _, version: version}} =
          EventStoreTestEventBus.load_snapshot(state.stream_name)

        assert version == 1
      end

      test "then snapshot should have correct title", state do
        {:ok, %SnapshotData{payload: %TestSnapshot{title: title}, meta_data: _, version: _}} =
          EventStoreTestEventBus.load_snapshot(state.stream_name)

        assert title == "title"
      end
    end

    describe "When storing two struct snapshots" do
      setup do
        stream_name = UUID.uuid4()

        EventStoreTestEventBus.append_snapshot(
          stream_name,
          {%TestSnapshot{title: "title1"}, %{}},
          1
        )

        EventStoreTestEventBus.append_snapshot(
          stream_name,
          {%TestSnapshot{title: "title2"}, %{}},
          2
        )

        {:ok, stream_name: stream_name}
      end

      test "then latest snapshot can be loaded", state do
        assert {:ok, %SnapshotData{payload: _, meta_data: _, version: _}} =
                 EventStoreTestEventBus.load_snapshot(state.stream_name)
      end

      test "then version 2 is returned when loading", state do
        {:ok, %SnapshotData{payload: _, meta_data: _, version: version}} =
          EventStoreTestEventBus.load_snapshot(state.stream_name)

        assert version == 2
      end

      test "then snapshot should have correct title", state do
        {:ok, %SnapshotData{payload: %TestSnapshot{title: title}, meta_data: _, version: _}} =
          EventStoreTestEventBus.load_snapshot(state.stream_name)

        assert title == "title2"
      end

      test "then version 1 is returned when loading with max_version", state do
        {:ok, %SnapshotData{payload: _, meta_data: _, version: version}} =
          EventStoreTestEventBus.load_snapshot(state.stream_name, 1)

        assert version == 1
      end

      test "then snapshot should have correct title when loading with max_version", state do
        {:ok, %SnapshotData{payload: %TestSnapshot{title: title}, meta_data: _, version: _}} =
          EventStoreTestEventBus.load_snapshot(state.stream_name, 1)

        assert title == "title1"
      end
    end

    describe "When storing two snapshots and deleting version 1" do
      setup do
        stream_name = UUID.uuid4()

        EventStoreTestEventBus.append_snapshot(
          stream_name,
          {{:test_snapshot, %{title: "title1"}}, %{}},
          1
        )

        EventStoreTestEventBus.append_snapshot(
          stream_name,
          {{:test_snapshot, %{title: "title2"}}, %{}},
          2
        )

        response = EventStoreTestEventBus.delete_snapshots(stream_name, 1)

        {:ok, stream_name: stream_name, response: response}
      end

      test "then response should be :ok", state do
        assert state.response == :ok
      end

      test "then latest snapshot can be loaded", state do
        assert {:ok, %SnapshotData{payload: _, meta_data: _, version: _}} =
                 EventStoreTestEventBus.load_snapshot(state.stream_name)
      end

      test "then version 2 is returned when loading", state do
        {:ok, %SnapshotData{payload: _, meta_data: _, version: version}} =
          EventStoreTestEventBus.load_snapshot(state.stream_name)

        assert version == 2
      end

      test "then snapshot should have correct title", state do
        {:ok, %SnapshotData{payload: {:test_snapshot, payload}, meta_data: _, version: _}} =
          EventStoreTestEventBus.load_snapshot(state.stream_name)

        assert payload.title == "title2"
      end

      test "then nil is returned when loading with max_version", state do
        assert {:ok, nil} = EventStoreTestEventBus.load_snapshot(state.stream_name, 1)
      end
    end

    defp assert_implements(module, behaviour) do
      all = Keyword.take(module.__info__(:attributes), [:behaviour])

      assert [behaviour] in Keyword.values(all)
    end
  end
end
