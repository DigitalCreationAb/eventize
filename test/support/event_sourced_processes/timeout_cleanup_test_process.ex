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

  @impl true
  def execute_call({:timeout, timeout}, _from, _context) do
    {[{:timeout_requested, %{seconds: timeout}}], :ok}
  end

  @impl true
  def cleanup({:timeout_requested, %{seconds: timeout}}, _context) do
    {:timeout, timeout}
  end
end
