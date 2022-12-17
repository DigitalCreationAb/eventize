defmodule EventStoreTests do
  defmacro __using__(event_store_module) do
    quote do
      use ExUnit.Case

      alias Reactive.Persistence.EventBus.EventData

      doctest unquote(__MODULE__)

      defmodule EventStoreTestEventBus do
        @moduledoc false

        @behaviour Reactive.Persistence.EventBus

        alias Reactive.Persistence.EventStore.AppendCommand
        alias Reactive.Persistence.EventStore.LoadQuery

        def load_events(stream_name, start \\ :start, max_count \\ :all) do
          GenServer.call(TestEventStore, %LoadQuery{
            stream_name: stream_name,
            start: start,
            max_count: max_count
          })
        end

        def append_events(stream_name, events, expected_version \\ :any) do
          GenServer.call(TestEventStore, %AppendCommand{
            stream_name: stream_name,
            events: events,
            expected_version: expected_version
          })
        end

        def delete(stream_name, version) do
          GenServer.call(
            TestEventStore,
            {:delete_events, stream_name, version}
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

          EventStoreTestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title"}}, %{}}])

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

          EventStoreTestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title1"}}, %{}}])
          EventStoreTestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title2"}}, %{}}])

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

          EventStoreTestEventBus.append_events(stream_name, [{%TitleUpdated{title: "title1"}, %{}}])
          EventStoreTestEventBus.append_events(stream_name, [{%TitleUpdated{title: "title2"}, %{}}])

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
            EventStoreTestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title1"}}, %{}}], 0)

          second_response =
            EventStoreTestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title2"}}, %{}}], 0)

          {:ok,
           stream_name: stream_name, first_response: first_response, second_response: second_response}
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
            EventStoreTestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title1"}}, %{}}], 0)

          second_response =
            EventStoreTestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title2"}}, %{}}], 1)

          {:ok,
           stream_name: stream_name, first_response: first_response, second_response: second_response}
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
          assert {:ok, 1} = state.first_response
        end

        test "then second response is ok", state do
          assert {:ok, 2} = state.second_response
        end
      end

      describe "When storing two events and loading from start with max_count 1" do
        setup do
          stream_name = UUID.uuid4()

          EventStoreTestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title1"}}, %{}}], 0)
          EventStoreTestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title2"}}, %{}}], 1)

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

          EventStoreTestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title1"}}, %{}}], 0)
          EventStoreTestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title2"}}, %{}}], 1)

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

          EventStoreTestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title1"}}, %{}}], 0)
          EventStoreTestEventBus.append_events(stream_name, [{{:title_updated, %{title: "title2"}}, %{}}], 1)

          response = EventStoreTestEventBus.delete(stream_name, 1)

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
    end
  end
end
