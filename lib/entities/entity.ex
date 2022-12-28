defmodule Eventize.Entities.Entity do
  @moduledoc """
  Entity is a `GenServer` process used to provide access to an
  instance of an entity that can handle commands and apply events.
  """

  @doc """
  A callback used to start a entity.
  """
  @callback start(id :: String.t()) :: {:atom, map()} | :atom | map() | nil

  defmacro __using__(_) do
    quote do
      use GenServer
      alias Eventize.Entities.Entity

      @before_compile Eventize.Entities.Entity
      @behaviour Eventize.Entities.Entity

      @doc """
      Initializes the entity with the initial state.
      """
      def init(%{id: id}) do
        {:ok, initialize_state(id)}
      end

      defoverridable init: 1

      @doc """
      Handle any command sent to the entity.
      """
      def handle_cast(
            {:execute, command, %{message_id: message_id, correlation_id: correlation_id}},
            %{id: id, state: state, behavior: behavior} = entity_state
          ) do
        {new_state, events} =
          case behavior.execute_cast(command, %{
                 id: id,
                 state: state,
                 causation_id: message_id,
                 correlation_id: correlation_id
               }) do
            events when is_list(events) ->
              apply_events(events, entity_state, %{
                causation_id: message_id,
                correlation_id: correlation_id
              })

            _ ->
              {entity_state, []}
          end

        handle_cleanup({new_state, events}, {:noreply, new_state})
      end

      def handle_cast({:execute, command, %{message_id: message_id}}, entity_state),
        do:
          handle_cast(
            {:execute, command, %{message_id: message_id, correlation_id: UUID.uuid4()}},
            entity_state
          )

      def handle_cast({:execute, command, %{correlation_id: correlation_id}}, entity_state),
        do:
          handle_cast(
            {:execute, command, %{message_id: UUID.uuid4(), correlation_id: correlation_id}},
            entity_state
          )

      def handle_cast({:execute, command}, entity_state),
        do:
          handle_cast(
            {:execute, command, %{message_id: UUID.uuid4(), correlation_id: UUID.uuid4()}},
            entity_state
          )

      @doc """
      Handle any command sent to the entity where the sender wants a response back.
      """
      def handle_call(
            {:execute, command, %{message_id: message_id, correlation_id: correlation_id}},
            from,
            %{id: id, state: state, behavior: behavior} = entity_state
          ) do
        {response, new_state, events} =
          case behavior.execute_call(command, from, %{
                 id: id,
                 state: state,
                 causation_id: message_id,
                 correlation_id: correlation_id
               }) do
            {events, response} when is_list(events) ->
              {state, events} =
                apply_events(events, entity_state, %{
                  causation_id: message_id,
                  correlation_id: correlation_id
                })

              {response, state, events}

            events when is_list(events) ->
              {state, events} =
                apply_events(events, entity_state, %{
                  causation_id: message_id,
                  correlation_id: correlation_id
                })

              {:ok, state, events}

            response ->
              {response, entity_state, []}

            _ ->
              {:ok, entity_state, []}
          end

        handle_cleanup({new_state, events}, {:reply, response, new_state})
      end

      def handle_call({:execute, command, %{message_id: message_id}}, from, entity_state),
        do:
          handle_call(
            {:execute, command, %{message_id: message_id, correlation_id: UUID.uuid4()}},
            from,
            entity_state
          )

      def handle_call({:execute, command, %{correlation_id: correlation_id}}, from, entity_state),
        do:
          handle_call(
            {:execute, command, %{message_id: UUID.uuid4(), correlation_id: correlation_id}},
            from,
            entity_state
          )

      def handle_call({:execute, command}, from, entity_state),
        do:
          handle_call(
            {:execute, command, %{message_id: UUID.uuid4(), correlation_id: UUID.uuid4()}},
            from,
            entity_state
          )

      @doc """
      Stops the entity after the desired timeout.
      """
      def handle_info(:timeout, state) do
        {:stop, :normal, state}
      end

      defp handle_cleanup({entity_state, events}, default_return) do
        events
        |> Enum.map(fn event -> cleanup(event, entity_state.state) end)
        |> Enum.map(fn cleanup_data ->
          case cleanup_data do
            list when is_list(list) ->
              list

            item ->
              [item]
          end
        end)
        |> Enum.concat()
        |> Enum.reduce(default_return, fn cleanup, current_response ->
          run_cleanup(cleanup, current_response, entity_state)
        end)
      end

      defoverridable handle_cleanup: 2

      defp run_cleanup(:stop, current_return, entity_state),
        do: run_cleanup({:stop, :normal}, current_return, entity_state)

      defp run_cleanup({:stop, reason}, current_return, _entity_state) do
        case current_return do
          {:reply, reply, new_state} ->
            {:stop, reason, reply, new_state}

          {:reply, reply, new_state, _} ->
            {:stop, reason, reply, new_state}

          {:noreply, new_state} ->
            {:stop, reason, new_state}

          {:noreply, new_state, _} ->
            {:stop, reason, new_state}

          {:stop, _, reply, new_state} ->
            {:stop, reason, reply, new_state}

          {:stop, _, new_state} ->
            {:stop, reason, new_state}
        end
      end

      defp run_cleanup({:timeout, timeout}, current_return, _entity_state) do
        case current_return do
          {:reply, reply, new_state} ->
            {:reply, reply, new_state, timeout}

          {:reply, reply, new_state, current_timeout}
          when (is_integer(current_timeout) and timeout < current_timeout) or
                 current_timeout == :hibernate ->
            {:reply, reply, new_state, timeout}

          {:noreply, new_state} ->
            {:noreply, new_state, timeout}

          {:noreply, new_state, current_timeout}
          when (is_integer(current_timeout) and timeout < current_timeout) or
                 current_timeout == :hibernate ->
            {:noreply, new_state, timeout}

          _ ->
            current_return
        end
      end

      defp run_cleanup(:hibernate, current_return, _entity_state) do
        case current_return do
          {:reply, reply, new_state} ->
            {:reply, reply, new_state, :hibernate}

          {:noreply, new_state} ->
            {:noreply, new_state, :hibernate}

          _ ->
            current_return
        end
      end

      defp run_cleanup({:continue, _data} = continuation, current_return, _entity_state) do
        case current_return do
          {:reply, reply, new_state} ->
            {:reply, reply, new_state, continuation}

          {:reply, reply, new_state, _current_timeout} ->
            {:reply, reply, new_state, continuation}

          {:noreply, new_state} ->
            {:noreply, new_state, continuation}

          {:noreply, new_state, _current_timeout} ->
            {:noreply, new_state, continuation}

          _ ->
            current_return
        end
      end

      defp initialize_state(id) do
        case start(id) do
          nil ->
            %{id: id, behavior: __MODULE__, state: nil}

          {behavior, initial_state} when is_atom(behavior) ->
            %{id: id, behavior: behavior, state: initial_state}

          behavior when is_atom(behavior) ->
            %{id: id, behavior: behavior, state: nil}

          initial_state ->
            %{id: id, behavior: __MODULE__, state: initial_state}
        end
      end

      defp apply_events(
             events,
             %{state: state, behavior: behavior} = entity_state,
             %{} = _additional_meta_data
           )
           when is_list(events) do
        {new_state, new_behavior} = run_event_handlers(events, state, behavior)

        {%{entity_state | state: new_state, behavior: new_behavior}, events}
      end

      defoverridable apply_events: 3

      defp run_event_handlers(events, state, current_behavior) when is_list(events) do
        Enum.reduce(events, {state, current_behavior}, fn event, {state, behavior} ->
          case run_event_applier(event, state) do
            {new_state, nil} -> {new_state, __MODULE__}
            {new_state, new_behavior} -> {new_state, new_behavior}
            new_state -> {new_state, behavior}
          end
        end)
      end

      defp run_event_applier(event, state) do
        apply_event(event, state)
      end

      defoverridable run_event_applier: 2
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def start(_id), do: %{}

      defoverridable start: 1

      defp apply_event(_event, state), do: state

      defp cleanup(_event, _state), do: []

      defp run_cleanup(_cleanup, current_return, _state), do: current_return
    end
  end
end
