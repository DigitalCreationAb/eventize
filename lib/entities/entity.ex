defmodule Reactive.Entities.Entity do
  @moduledoc """
  Entity is a `GenServer` process used to provide access to an
  instance of an entity that can handle commands and apply events.

  A entity is started whenever a command is sent to a instance.
  By default, an entity process will run indefinitely once started.
  Its lifespan may be controlled by implementing the `c:get_lifespan/2`
  function.
  """

  @doc """
  A callback used to start a entity.
  """
  @callback start(id :: Any) :: {:atom, %{}} | :atom | %{} | nil

  defmacro __using__(_) do
    quote do
      use GenServer
      alias Reactive.Entities.Entity

      @before_compile Reactive.Entities.Entity
      @behaviour Reactive.Entities.Entity

      @doc """
      Initializes the entity with the initial state.
      """
      def init(%{:id => id}) do
        {:ok, initialize_state(id)}
      end

      defoverridable init: 1

      @doc """
      Handle any command sent to the entity.
      """
      def handle_cast({:execute, command}, entity_state) do
        {_, new_state, life_span} = execute_command(command, entity_state)

        case life_span do
          :stop -> {:stop, :normal, new_state}
          {:stop, reason} -> {:stop, reason, new_state}
          life_span -> {:noreply, new_state, life_span}
        end
      end

      @doc """
      Handle any command sent to the entity where the sender wants a response back.
      """
      def handle_call({:execute, command}, _from, entity_state) do
        {response, new_state, life_span} = execute_command(command, entity_state)

        case life_span do
          :stop -> {:stop, :normal, response, new_state}
          {:stop, reason} -> {:stop, reason, response, new_state}
          life_span -> {:reply, response, new_state, life_span}
        end
      end

      defp initialize_state(id) do
        case start(id) do
          nil ->
            %{id: id, behavior: __MODULE__, state: nil}

          {behavior, initial_state} ->
            %{id: id, behavior: behavior, state: initial_state}

          behavior when is_atom(behavior) ->
            %{id: id, behavior: behavior, state: nil}

          initial_state ->
            %{id: id, behavior: __MODULE__, state: initial_state}
        end
      end

      defp execute_command(
             command,
             %{:id => id, :state => state, :behavior => behavior} = entity_state
           ) do
        case behavior.execute(command, %{id: id, state: state}) do
          {events, response} when is_list(events) ->
            {state, behavior, life_span} = apply_events(events, entity_state)

            {response, %{id: id, state: state, behavior: behavior}, life_span}

          events when is_list(events) ->
            {state, behavior, life_span} = apply_events(events, entity_state)

            {nil, %{id: id, state: state, behavior: behavior}, life_span}

          response ->
            {response, %{id: id, state: state, behavior: behavior}, :infinity}

          _ ->
            {nil, %{id: id, state: state, behavior: behavior}, :infinity}
        end
      end

      defp apply_events(events, %{:state => state, :behavior => behavior})
           when is_list(events) do
        run_event_handlers(events, state, behavior)
      end

      defoverridable apply_events: 2

      defp run_event_handlers(events, state, current_behavior) when is_list(events) do
        {new_state, behavior} =
          Enum.reduce(events, {state, current_behavior}, fn event, {state, behavior} ->
            case on(state, event) do
              {new_state, nil} -> {new_state, behavior}
              {new_state, new_behavior} -> {new_state, new_behavior}
              new_state -> {new_state, behavior}
            end
          end)

        life_span =
          Enum.reduce(events, :infinity, fn event, current ->
            case get_lifespan(event, new_state) do
              :keep -> current
              new_life_span -> new_life_span
            end
          end)

        {new_state, behavior, life_span}
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      @impl true
      def start(_id), do: %{}

      defoverridable start: 1

      defp on(state, _event), do: state

      defp get_lifespan(_event, _state), do: :keep
    end
  end
end
