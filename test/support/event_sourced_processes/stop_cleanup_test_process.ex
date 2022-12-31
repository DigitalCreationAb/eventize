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

  def execute_call(:stop, _from, _context) do
    {[{:stop_requested, %{}}], :ok}
  end

  def cleanup({:stop_requested, _}, _state) do
    :stop
  end
end
