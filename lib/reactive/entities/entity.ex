defmodule Reactive.Entities.Entity do
  @callback start(id :: Any) :: {:atom, %{}} | :atom | %{} | nil

  @optional_callbacks start: 1
  
  defmodule EntityState do
    defstruct id: nil,
              state: %{},
              behavior: nil
  end
  
  defmodule ExecutionContext do
    defstruct id: nil,
              state: %{}
  end

  defmacro __using__(_) do
    quote do
      use GenServer
      alias Reactive.Entities.Entity

      @before_compile Reactive.Entities.Entity
      @behaviour Reactive.Entities.Entity

      def child_spec(id) do
        %{
          id: get_id(id),
          start: {__MODULE__, :start_link, [id]},
          type: :worker
        }
      end
      
      def start_link(id) do
        GenServer.start_link(
          __MODULE__,
          id,
          name: {:global, get_id(id)}
        )
      end
      
      def init(id) do
        {:ok, initialize_state(id)}
      end
      
      defoverridable [init: 1]
      
      def handle_cast({:execute, command}, entity_state) when is_struct(command) do
        {_, new_state} = execute_command(command, entity_state)

        {:noreply, new_state}
      end
      
      def handle_call({:execute, command}, _from, entity_state) when is_struct(command) do
        {response, new_state} = execute_command(command, entity_state)

        {:reply, response, new_state}
      end

      defp initialize_state(id) do
        case start(id) do
          nil ->
            %EntityState{id: id, behavior: __MODULE__}
          {behavior, initial_state} ->
            %EntityState{id: id, behavior: behavior, state: initial_state}
          behavior when is_atom(behavior) ->
            %EntityState{id: id, behavior: behavior}
          initial_state ->
            %EntityState{id: id, behavior: __MODULE__, state: initial_state}
        end
      end
      
      defp get_id(entity_id) do
        "#{__MODULE__}-#{entity_id}"
      end
      
      defp execute_command(command, %EntityState{:id => id, :state => state, :behavior => behavior} = entity_state) when is_struct(command) do
        case behavior.execute(%ExecutionContext{id: id, state: state}, command) do
          {events, response} when is_list(events) ->
            {state, behavior} = apply_events(events, entity_state)

            {response, %EntityState{id: id, state: state, behavior: behavior}}
          events when is_list(events) ->
            {state, behavior} = apply_events(events, entity_state)

            {nil, %EntityState{id: id, state: state, behavior: behavior}}
          _ -> {nil, %EntityState{id: id, state: state, behavior: behavior}}
        end
      end
      
      defp apply_events(events, %EntityState{:id => _id, :state => state, :behavior => behavior}) when is_list(events) do
        run_event_handlers(events, state, behavior)
      end

      defoverridable [apply_events: 2]
      
      defp run_event_handlers(events, state, current_behavior) when is_list(events) do
        Enum.reduce(events, {state, current_behavior}, fn(event, {state, behavior}) ->
          case on(state, event) do
            {new_state, nil} -> {new_state, behavior}
            {new_state, new_behavior} -> {new_state, new_behavior}
            new_state -> {new_state, behavior}
          end
        end)
      end
    end
  end
  
  defmacro __before_compile__(_env) do
    quote do
      @impl true
      def start(_id), do: nil
      
      defoverridable [start: 1]
      
      defp on(state, _event), do: state
    end
  end
end
