defmodule Reactive.Persistence.EventStore do
  @moduledoc """
  EventStore is a `GenServer` process used to store
  events for `Reactive.Entities.Entity` instances.
  """

  defmodule EventData do
    @moduledoc """
    Represents a event with payload and a sequence number
    """

    defstruct [:payload, :meta_data, :sequence_number]
  end

  @type load_events_query :: %{
          stream_name: String.t(),
          start: :start | non_neg_integer(),
          max_count: :all | non_neg_integer()
        }

  @type append_events_command :: %{
          stream_name: String.t(),
          events: list({term(), map()}),
          expected_version: :any | non_neg_integer()
        }

  @type delete_events_command :: %{stream_name: String.t(), version: non_neg_integer()}

  @type events_response :: {:ok, non_neg_integer(), list(EventData)} | {:error, term()}

  @type delete_response :: :ok | {:error, term()}

  @callback execute_call(
              {:load_events, load_events_query()},
              GenServer.from(),
              term()
            ) ::
              {:reply, events_response(), term()}
              | {:reply, events_response(), term(),
                 timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | {:stop, term(), term(), term()}
              | {:stop, term(), term()}

  @callback execute_call({:append_events, append_events_command()}, GenServer.from(), term()) ::
              {:reply, events_response(), term()}
              | {:reply, events_response(), term(),
                 timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | {:stop, term(), term(), term()}
              | {:stop, term(), term()}

  @callback execute_call({:delete_events, delete_events_command()}, GenServer.from(), term()) ::
              {:reply, delete_response(), term()}
              | {:reply, delete_response(), term(),
                 timeout() | :hibernate | {:continue, continue_arg :: term()}}
              | {:stop, term(), term(), term()}
              | {:stop, term(), term()}

  defmacro __using__(_) do
    quote do
      use GenServer

      @behaviour Reactive.Persistence.EventStore
      alias Reactive.Persistence.EventStore.EventData

      def handle_call({:load_events, _query} = query, from, state),
        do: execute_call(query, from, state)

      def handle_call({:append_events, _cmd} = cmd, from, state),
        do: execute_call(cmd, from, state)

      def handle_call({:delete_events, _cmd} = cmd, from, state),
        do: execute_call(cmd, from, state)
    end
  end
end
