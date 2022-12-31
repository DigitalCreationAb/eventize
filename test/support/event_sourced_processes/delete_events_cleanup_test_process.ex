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

  @impl Eventize.EventSourcedProcess
  def execute_call({:delete_events, to}, _from, _context) do
    {[{:delete_requested, to}], :ok}
  end

  @impl Eventize.EventSourcedProcess
  def execute_call(:ping, _from, _context) do
    :pong
  end

  @impl Eventize.EventSourcedProcess
  def execute_cast({:delete_events, to}, _context) do
    [{:delete_requested, to}]
  end

  @impl Eventize.EventSourcedProcess.Cleanup
  def cleanup({:delete_requested, to}, _state) do
    {:delete_events, to}
  end
end
