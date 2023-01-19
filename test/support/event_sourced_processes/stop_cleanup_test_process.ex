defmodule Eventize.StopCleanupTestProcess do
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
  def execute_call(:stop, _from, _context) do
    {[{:stop_requested, %{}}], :ok}
  end

  @impl true
  def cleanup({:stop_requested, _}, _context) do
    :stop
  end
end
