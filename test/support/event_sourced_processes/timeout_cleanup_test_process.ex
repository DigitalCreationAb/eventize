defmodule Eventize.TimeoutCleanupTestProcess do
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
  def execute_call({:timeout, timeout}, _from, _context) do
    {[{:timeout_requested, %{seconds: timeout}}], :ok}
  end

  @impl Eventize.EventSourcedProcess.Cleanup
  def cleanup({:timeout_requested, %{seconds: timeout}}, _state) do
    {:timeout, timeout}
  end
end
