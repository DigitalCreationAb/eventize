defmodule Eventize.DeleteEventsCleanupTestProcess do
  @moduledoc false

  use Eventize.EventSourcedProcess

  def start_link(%{id: id} = data) do
    GenServer.start_link(
      __MODULE__,
      data,
      name: {:global, id}
    )
  end

  @impl true
  def execute_call({:delete_events, to}, _from, _context) do
    {[{:delete_requested, to}], :ok}
  end

  @impl true
  def execute_call(:ping, _from, _context) do
    :pong
  end

  @impl true
  def execute_cast({:delete_events, to}, _context) do
    [{:delete_requested, to}]
  end

  @impl true
  def cleanup({:delete_requested, to}, _context) do
    {:delete_events, to}
  end
end
