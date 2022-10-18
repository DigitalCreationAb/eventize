defmodule Reactive.Persistence.EventStore do
  use Supervisor
  
  @callback load(id :: Any, state :: struct()) :: {events :: Enumerable.t(), new_state :: struct()} | Enumerable.t()
  
  @callback append(id :: Any, events :: Enumerable.t(), state :: struct()) :: {:ok, new_state :: struct()} | :ok | {:error, error :: Any}
  
  def load_events(stream_name) do
    event_store = Application.get_env(:reactive, :event_store, Reactive.Persistence.InMemoryEventStore)
    
    GenServer.call({:global, event_store}, {:load, stream_name})
  end
  
  def append_events(stream_name, events) do
    event_store = Application.get_env(:reactive, :event_store, Reactive.Persistence.InMemoryEventStore)
    
    GenServer.call({:global, event_store}, {:append, stream_name, events})
  end

  def start_link() do
    Supervisor.start_link(__MODULE__, :ok)
  end

  @impl true
  def init(:ok) do
    children = [
      Application.get_env(:reactive, :event_store, Reactive.Persistence.InMemoryEventStore)
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
  
  defmacro __using__(_) do
    quote do
      use GenServer
      
      @behaviour Reactive.Persistence.EventStore

      def child_spec() do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, []},
          type: :worker
        }
      end

      def start_link(_) do
        GenServer.start_link(
          __MODULE__,
          __MODULE__,
          name: {:global, __MODULE__}
        )
      end

      def init(_) do
        {:ok, %{}}
      end

      defoverridable [init: 1]
      
      def handle_call({:load, id}, _from, state) do
        case load(id, state) do
          {events, new_state} ->
            {:reply, events, new_state}
          events ->
            {:reply, events, state}
        end
      end
      
      def handle_call({:append, id, events}, _from, state) do
        case append(id, events, state) do
          {:ok, new_state} -> {:reply, :ok, new_state}
          :ok -> {:reply, :ok, state}
          {:error, error} -> {:reply, {:error, error}, state}
        end
      end
    end
  end
end
