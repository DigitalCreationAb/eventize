defmodule EventSourcedProcess.CorrelationTest do
  use Eventize.Test.EventSourcedProcessTests, Eventize.CorrelationTestProcess

  describe "When calling with correlation_id and message_id" do
    setup do
      id = UUID.uuid4()
      correlation_id = UUID.uuid4()
      message_id = UUID.uuid4()

      pid = get_process(id)

      response =
        GenServer.call(
          pid,
          {{:test, %{}},
           %Eventize.EventSourcedProcess.MessageMetaData{
             correlation_id: correlation_id,
             message_id: message_id
           }}
        )

      {:ok,
       pid: pid,
       id: id,
       response: response,
       correlation_id: correlation_id,
       message_id: message_id}
    end

    test "then response should be have correct correlation_id and causation_id", state do
      assert state.response == %{
               correlation_id: state.correlation_id,
               causation_id: state.message_id
             }
    end

    test "then one event should be stored", state do
      assert length(get_events(state.id)) == 1
    end

    test "then a :test_event event should be stored", state do
      assert get_events(state.id) |> get_payload() == [
               {:test_event,
                %{correlation_id: state.correlation_id, causation_id: state.message_id}}
             ]
    end

    test "then event should have correct meta_data", state do
      assert get_events(state.id) |> get_meta_data() == [
               %{correlation_id: state.correlation_id, causation_id: state.message_id}
             ]
    end

    test "then process version should be 0", state do
      assert get_process_version(state.pid) == 0
    end

    test "then process should be in default behavior", state do
      assert get_current_behavior(state.pid) == Eventize.CorrelationTestProcess
    end

    test "then process should have correct state", state do
      assert get_process_state(state.pid) == %{
               event_correlation_id: state.correlation_id,
               event_causation_id: state.message_id,
               meta_data_correlation_id: state.correlation_id,
               meta_data_causation_id: state.message_id
             }
    end
  end

  describe "When calling with correlation_id" do
    setup do
      id = UUID.uuid4()
      correlation_id = UUID.uuid4()

      pid = get_process(id)

      response =
        GenServer.call(
          pid,
          {{:test, %{}},
           %Eventize.EventSourcedProcess.MessageMetaData{correlation_id: correlation_id}}
        )

      {:ok, pid: pid, id: id, response: response, correlation_id: correlation_id}
    end

    test "then one event should be stored", state do
      assert length(get_events(state.id)) == 1
    end

    test "then a :test_event event should be stored with random causation_id", state do
      assert [{:test_event, %{correlation_id: _, causation_id: _}}] =
               get_events(state.id) |> get_payload()
    end
  end

  describe "When calling with message_id" do
    setup do
      id = UUID.uuid4()
      message_id = UUID.uuid4()

      pid = get_process(id)

      response =
        GenServer.call(
          pid,
          {{:test, %{}}, %Eventize.EventSourcedProcess.MessageMetaData{message_id: message_id}}
        )

      {:ok, pid: pid, id: id, response: response, message_id: message_id}
    end

    test "then one event should be stored", state do
      assert length(get_events(state.id)) == 1
    end

    test "then a :test_event event should be stored with random correlation_id", state do
      assert [{:test_event, %{correlation_id: _, causation_id: _}}] =
               get_events(state.id) |> get_payload()
    end
  end

  describe "When casting with correlation_id and message_id" do
    setup do
      id = UUID.uuid4()
      correlation_id = UUID.uuid4()
      message_id = UUID.uuid4()

      pid = get_process(id)

      GenServer.cast(
        pid,
        {{:test, %{}},
         %Eventize.EventSourcedProcess.MessageMetaData{
           correlation_id: correlation_id,
           message_id: message_id
         }}
      )

      :pong = GenServer.call(pid, :ping)

      {:ok, pid: pid, id: id, correlation_id: correlation_id, message_id: message_id}
    end

    test "then one event should be stored", state do
      assert length(get_events(state.id)) == 1
    end

    test "then a :test_event event should be stored", state do
      assert get_events(state.id) |> get_payload() == [
               {:test_event,
                %{correlation_id: state.correlation_id, causation_id: state.message_id}}
             ]
    end

    test "then event should have correct meta_data", state do
      assert get_events(state.id) |> get_meta_data() == [
               %{correlation_id: state.correlation_id, causation_id: state.message_id}
             ]
    end

    test "then process version should be 0", state do
      assert get_process_version(state.pid) == 0
    end

    test "then process should be in default behavior", state do
      assert get_current_behavior(state.pid) == Eventize.CorrelationTestProcess
    end

    test "then process should have correct state", state do
      assert get_process_state(state.pid) == %{
               event_correlation_id: state.correlation_id,
               event_causation_id: state.message_id,
               meta_data_correlation_id: state.correlation_id,
               meta_data_causation_id: state.message_id
             }
    end
  end

  describe "When casting with correlation_id" do
    setup do
      id = UUID.uuid4()
      correlation_id = UUID.uuid4()

      pid = get_process(id)

      GenServer.cast(
        pid,
        {{:test, %{}},
         %Eventize.EventSourcedProcess.MessageMetaData{correlation_id: correlation_id}}
      )

      :pong = GenServer.call(pid, :ping)

      {:ok, pid: pid, id: id, correlation_id: correlation_id}
    end

    test "then one event should be stored", state do
      assert length(get_events(state.id)) == 1
    end

    test "then a :test_event event should be stored with random causation_id", state do
      assert [{:test_event, %{correlation_id: _, causation_id: _}}] =
               get_events(state.id) |> get_payload()
    end
  end

  describe "When casting with message_id" do
    setup do
      id = UUID.uuid4()
      message_id = UUID.uuid4()

      pid = get_process(id)

      GenServer.cast(
        pid,
        {{:test, %{}}, %Eventize.EventSourcedProcess.MessageMetaData{message_id: message_id}}
      )

      :pong = GenServer.call(pid, :ping)

      {:ok, pid: pid, id: id, message_id: message_id}
    end

    test "then one event should be stored", state do
      assert length(get_events(state.id)) == 1
    end

    test "then a :test_event event should be stored with random correlation_id", state do
      assert [{:test_event, %{correlation_id: _, causation_id: _}}] =
               get_events(state.id) |> get_payload()
    end
  end
end
