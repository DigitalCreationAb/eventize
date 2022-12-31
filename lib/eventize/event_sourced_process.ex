defmodule Eventize.EventSourcedProcess do
  @moduledoc """
  EventSourcedProcess is a optininated `GenServer` that will
  use event sourcing to store its state as a sequence of events.

  Instead of using the normal `handle_call/3` and `handle_cast/2`
  callbacks you can now use `c:execute_call/3` and `c:execute_cast/2`.
  These function very similar, but instead of modifying the state
  you can return a list of events that should be applied. These
  events will be stored using the configured event bus and then
  applied to the process using the `c:apply_event/2` or `c:apply_event/3`
  callback.
  All stored events will also be read on startup and the `c:apply_event/3`
  functions will be called then as well to make sure that the state
  is up to date.
  """

  @callback execute_call(term(), pid(), map()) :: {list(), term()} | list() | term()

  @callback execute_cast(term(), map()) :: list() | nil

  @optional_callbacks execute_call: 3,
                      execute_cast: 2

  defmacro __using__(_) do
    quote location: :keep, generated: true do
      use GenServer

      use Eventize.EventSourcedProcess.Initialization
      use Eventize.EventSourcedProcess.Cleanup
      use Eventize.EventSourcedProcess.EventApplyer

      alias Eventize.EventSourcedProcessState

      @behaviour Eventize.EventSourcedProcess

      @doc false
      @impl GenServer
      def handle_cast(
            {message, %{message_id: message_id, correlation_id: correlation_id}},
            %EventSourcedProcessState{id: id, state: state, behavior: behavior} = process_state
          ) do
        {new_state, events} =
          case behavior.execute_cast(message, %{
                 id: id,
                 state: state,
                 causation_id: message_id,
                 correlation_id: correlation_id
               }) do
            events when is_list(events) ->
              apply_events(events, process_state, %{
                causation_id: message_id,
                correlation_id: correlation_id
              })

            _ ->
              {process_state, []}
          end

        handle_cleanup({new_state, events}, {:noreply, new_state})
      end

      @impl GenServer
      def handle_cast({message, %{message_id: message_id}}, process_state),
        do:
          handle_cast(
            {message, %{message_id: message_id, correlation_id: UUID.uuid4()}},
            process_state
          )

      @impl GenServer
      def handle_cast({message, %{correlation_id: correlation_id}}, process_state),
        do:
          handle_cast(
            {message, %{message_id: UUID.uuid4(), correlation_id: correlation_id}},
            process_state
          )

      @impl GenServer
      def handle_cast(message, process_state),
        do:
          handle_cast(
            {message, %{message_id: UUID.uuid4(), correlation_id: UUID.uuid4()}},
            process_state
          )

      @doc false
      @impl GenServer
      def handle_call(
            {message, %{message_id: message_id, correlation_id: correlation_id}},
            from,
            %EventSourcedProcessState{id: id, state: state, behavior: behavior} = process_state
          ) do
        {response, new_state, events} =
          case behavior.execute_call(message, from, %{
                 id: id,
                 state: state,
                 causation_id: message_id,
                 correlation_id: correlation_id
               }) do
            {events, response} when is_list(events) ->
              {state, events} =
                apply_events(events, process_state, %{
                  causation_id: message_id,
                  correlation_id: correlation_id
                })

              {response, state, events}

            events when is_list(events) ->
              {state, events} =
                apply_events(events, process_state, %{
                  causation_id: message_id,
                  correlation_id: correlation_id
                })

              {:ok, state, events}

            response ->
              {response, process_state, []}
          end

        handle_cleanup({new_state, events}, {:reply, response, new_state})
      end

      @impl GenServer
      def handle_call({message, %{message_id: message_id}}, from, process_state),
        do:
          handle_call(
            {message, %{message_id: message_id, correlation_id: UUID.uuid4()}},
            from,
            process_state
          )

      @impl GenServer
      def handle_call({message, %{correlation_id: correlation_id}}, from, process_state),
        do:
          handle_call(
            {message, %{message_id: UUID.uuid4(), correlation_id: correlation_id}},
            from,
            process_state
          )

      @impl GenServer
      def handle_call(message, from, process_state),
        do:
          handle_call(
            {message, %{message_id: UUID.uuid4(), correlation_id: UUID.uuid4()}},
            from,
            process_state
          )
    end
  end
end
