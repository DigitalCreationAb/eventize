defmodule Reactive.Persistence.EventStore do
  @moduledoc """
  EventStore is a `GenServer` process used to store
  events for `Reactive.Entities.Entity` instances.
  """

  @doc """
  A callback used to load all the events for a stream.
  """
  @callback load(id :: String.t(), state :: map) ::
              {events :: Enumerable.t(), new_state :: map} | Enumerable.t()

  @doc """
  A callback used to append new events to a stream.
  """
  @callback append(id :: String.t(), events :: Enumerable.t(), state :: map) ::
              {:ok, new_state :: map} | :ok | {:error, error :: term}

  defmacro __using__(_) do
    quote do
      use GenServer

      @behaviour Reactive.Persistence.EventStore

      @doc """
      Loads all events for a stream.
      """
      def handle_call({:load, id}, _from, state) do
        case load(id, state) do
          {events, new_state} ->
            {:reply, events, new_state}

          events ->
            {:reply, events, state}
        end
      end

      @doc """
      Appends a list of events to a stream.
      """
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
