defmodule Eventize.EventStoreTests do
  defmacro __using__(event_store_module) do
    quote do
      use ExUnit.Case

      alias Eventize.Persistence.EventStore.EventData
      alias Eventize.Persistence.EventStore.SnapshotData

      doctest unquote(__MODULE__)

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

        def append_snapshot(stream_name, snapshot, version, expected_version \\ :any) do
          GenServer.call(
            TestEventStore,
            {:append_snapshot,
             %{
               stream_name: stream_name,
               snapshot: snapshot,
               version: version,
               expected_version: expected_version
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

      setup_all do
        start_supervised({unquote(event_store_module), name: TestEventStore})

        :ok
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
          {:ok, _version, events} = EventStoreTestEventBus.load_events(state.stream_name)

          assert length(events) == 1
        end

        test "then version 1 is returned when loading", state do
          {:ok, version, _events} = EventStoreTestEventBus.load_events(state.stream_name)

          assert version == 1
        end

        test "then event should have correct title", state do
          {:ok, _version, [%EventData{payload: {:title_updated, first}}]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert first.title == "title"
        end

        test "then event should have correct sequence number", state do
          {:ok, _version, [%EventData{sequence_number: sequence_number}]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert sequence_number == 1
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
          {:ok, _version, events} = EventStoreTestEventBus.load_events(state.stream_name)

          assert length(events) == 2
        end

        test "then version 2 is returned when loading", state do
          {:ok, version, _events} = EventStoreTestEventBus.load_events(state.stream_name)

          assert version == 2
        end

        test "then first event should have correct title", state do
          {:ok, _version, [%EventData{payload: {:title_updated, first}}, _]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert first.title == "title1"
        end

        test "then second event should have correct title", state do
          {:ok, _version, [_, %EventData{payload: {:title_updated, second}}]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert second.title == "title2"
        end

        test "then first event should have correct sequence number", state do
          {:ok, _version, [%EventData{sequence_number: sequence_number}, _]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert sequence_number == 1
        end

        test "then second event should have correct sequence number", state do
          {:ok, _version, [_, %EventData{sequence_number: sequence_number}]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert sequence_number == 2
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
          {:ok, _version, events} = EventStoreTestEventBus.load_events(state.stream_name)

          assert length(events) == 2
        end

        test "then version 2 is returned when loading", state do
          {:ok, version, _events} = EventStoreTestEventBus.load_events(state.stream_name)

          assert version == 2
        end

        test "then first event should have correct title", state do
          {:ok, _version, [%EventData{payload: {:title_updated, first}}, _]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert first.title == "title1"
        end

        test "then second event should have correct title", state do
          {:ok, _version, [_, %EventData{payload: {:title_updated, second}}]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert second.title == "title2"
        end

        test "then first event should have correct sequence number", state do
          {:ok, _version, [%EventData{sequence_number: sequence_number}, _]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert sequence_number == 1
        end

        test "then second event should have correct sequence number", state do
          {:ok, _version, [_, %EventData{sequence_number: sequence_number}]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert sequence_number == 2
        end
      end

      describe "When storing single struct event" do
        setup do
          stream_name = UUID.uuid4()

          EventStoreTestEventBus.append_events(stream_name, [{%TitleUpdated{title: "title"}, %{}}])

          {:ok, stream_name: stream_name}
        end

        test "then one event can be loaded", state do
          {:ok, _version, events} = EventStoreTestEventBus.load_events(state.stream_name)

          assert length(events) == 1
        end

        test "then version 1 is returned when loading", state do
          {:ok, version, _events} = EventStoreTestEventBus.load_events(state.stream_name)

          assert version == 1
        end

        test "then event should have correct title", state do
          {:ok, _version, [%EventData{payload: %TitleUpdated{} = first}]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert first.title == "title"
        end

        test "then event should have correct sequence number", state do
          {:ok, _version, [%EventData{sequence_number: sequence_number}]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert sequence_number == 1
        end
      end

      describe "When storing two struct events" do
        setup do
          stream_name = UUID.uuid4()

          EventStoreTestEventBus.append_events(stream_name, [
            {%TitleUpdated{title: "title1"}, %{}},
            {%TitleUpdated{title: "title2"}, %{}}
          ])

          {:ok, stream_name: stream_name}
        end

        test "then two event can be loaded", state do
          {:ok, _version, events} = EventStoreTestEventBus.load_events(state.stream_name)

          assert length(events) == 2
        end

        test "then version 2 is returned when loading", state do
          {:ok, version, _events} = EventStoreTestEventBus.load_events(state.stream_name)

          assert version == 2
        end

        test "then first event should have correct title", state do
          {:ok, _version, [%EventData{payload: %TitleUpdated{} = first}, _]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert first.title == "title1"
        end

        test "then second event should have correct title", state do
          {:ok, _version, [_, %EventData{payload: %TitleUpdated{} = second}]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert second.title == "title2"
        end

        test "then first event should have correct sequence number", state do
          {:ok, _version, [%EventData{sequence_number: sequence_number}, _]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert sequence_number == 1
        end

        test "then second event should have correct sequence number", state do
          {:ok, _version, [_, %EventData{sequence_number: sequence_number}]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert sequence_number == 2
        end
      end

      describe "When storing two struct events in two transactions" do
        setup do
          stream_name = UUID.uuid4()

          EventStoreTestEventBus.append_events(stream_name, [
            {%TitleUpdated{title: "title1"}, %{}}
          ])

          EventStoreTestEventBus.append_events(stream_name, [
            {%TitleUpdated{title: "title2"}, %{}}
          ])

          {:ok, stream_name: stream_name}
        end

        test "then two event can be loaded", state do
          {:ok, _version, events} = EventStoreTestEventBus.load_events(state.stream_name)

          assert length(events) == 2
        end

        test "then version 2 is returned when loading", state do
          {:ok, version, _events} = EventStoreTestEventBus.load_events(state.stream_name)

          assert version == 2
        end

        test "then first event should have correct title", state do
          {:ok, _version, [%EventData{payload: %TitleUpdated{} = first}, _]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert first.title == "title1"
        end

        test "then second event should have correct title", state do
          {:ok, _version, [_, %EventData{payload: %TitleUpdated{} = second}]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert second.title == "title2"
        end

        test "then first event should have correct sequence number", state do
          {:ok, _version, [%EventData{sequence_number: sequence_number}, _]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert sequence_number == 1
        end

        test "then second event should have correct sequence number", state do
          {:ok, _version, [_, %EventData{sequence_number: sequence_number}]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert sequence_number == 2
        end
      end

      describe "When storing two events with expected version 0" do
        setup do
          stream_name = UUID.uuid4()

          first_response =
            EventStoreTestEventBus.append_events(
              stream_name,
              [{{:title_updated, %{title: "title1"}}, %{}}],
              0
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

        test "then one event can be loaded", state do
          {:ok, _version, events} = EventStoreTestEventBus.load_events(state.stream_name)

          assert length(events) == 1
        end

        test "then version 1 is returned when loading", state do
          {:ok, version, _events} = EventStoreTestEventBus.load_events(state.stream_name)

          assert version == 1
        end

        test "then first response is ok", state do
          assert {:ok, 1, _} = state.first_response
        end

        test "then second response is error", state do
          assert {:error,
                  {:expected_version_missmatch, %{current_version: 1, expected_version: 0}}} =
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
              0
            )

          second_response =
            EventStoreTestEventBus.append_events(
              stream_name,
              [{{:title_updated, %{title: "title2"}}, %{}}],
              1
            )

          {:ok,
           stream_name: stream_name,
           first_response: first_response,
           second_response: second_response}
        end

        test "then two event can be loaded", state do
          {:ok, _version, events} = EventStoreTestEventBus.load_events(state.stream_name)

          assert length(events) == 2
        end

        test "then version 2 is returned when loading", state do
          {:ok, version, _events} = EventStoreTestEventBus.load_events(state.stream_name)

          assert version == 2
        end

        test "then first response is ok", state do
          assert {:ok, 1, _} = state.first_response
        end

        test "then second response is ok", state do
          assert {:ok, 2, _} = state.second_response
        end
      end

      describe "When storing two events and loading from start with max_count 1" do
        setup do
          stream_name = UUID.uuid4()

          EventStoreTestEventBus.append_events(
            stream_name,
            [{{:title_updated, %{title: "title1"}}, %{}}],
            0
          )

          EventStoreTestEventBus.append_events(
            stream_name,
            [{{:title_updated, %{title: "title2"}}, %{}}],
            1
          )

          response = EventStoreTestEventBus.load_events(stream_name, :start, 1)

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

          EventStoreTestEventBus.append_events(
            stream_name,
            [{{:title_updated, %{title: "title1"}}, %{}}],
            0
          )

          EventStoreTestEventBus.append_events(
            stream_name,
            [{{:title_updated, %{title: "title2"}}, %{}}],
            1
          )

          response = EventStoreTestEventBus.load_events(stream_name, 2, 1)

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

      describe "When storing two events and deleting version 1" do
        setup do
          stream_name = UUID.uuid4()

          EventStoreTestEventBus.append_events(
            stream_name,
            [{{:title_updated, %{title: "title1"}}, %{}}],
            0
          )

          EventStoreTestEventBus.append_events(
            stream_name,
            [{{:title_updated, %{title: "title2"}}, %{}}],
            1
          )

          response = EventStoreTestEventBus.delete_events(stream_name, 1)

          {:ok, stream_name: stream_name, response: response}
        end

        test "then response should be :ok", state do
          assert state.response == :ok
        end

        test "then one event can be loaded", state do
          {:ok, _version, events} = EventStoreTestEventBus.load_events(state.stream_name)

          assert length(events) == 1
        end

        test "then version 2 is returned when loading", state do
          {:ok, version, _events} = EventStoreTestEventBus.load_events(state.stream_name)

          assert version == 2
        end

        test "then event should have correct title", state do
          {:ok, _version, [%EventData{payload: {:title_updated, first}}]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert first.title == "title2"
        end

        test "then event should have correct sequence number", state do
          {:ok, _version, [%EventData{sequence_number: sequence_number}]} =
            EventStoreTestEventBus.load_events(state.stream_name)

          assert sequence_number == 2
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
          {:ok,
           %SnapshotData{payload: {:test_snapshot, %{title: title}}, meta_data: _, version: _}} =
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

      describe "When storing snapshot with expected version 0 when there is a event stored" do
        setup do
          stream_name = UUID.uuid4()

          EventStoreTestEventBus.append_events(stream_name, [{{:test_event, %{}}, %{}}])

          response =
            EventStoreTestEventBus.append_snapshot(
              stream_name,
              {{:test_snapshot, %{title: "title1"}}, %{}},
              1,
              0
            )

          {:ok, stream_name: stream_name, response: response}
        end

        test "then no snapshot can be loaded", state do
          assert {:ok, nil} = EventStoreTestEventBus.load_snapshot(state.stream_name)
        end

        test "then response is error", state do
          assert {:error,
                  {:expected_version_missmatch, %{current_version: 1, expected_version: 0}}} =
                   state.response
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
    end
  end
end
