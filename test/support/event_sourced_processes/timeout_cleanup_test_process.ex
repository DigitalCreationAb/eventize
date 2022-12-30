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

  def execute_call({:timeout, timeout}, _from, _context) do
    {[{:timeout_requested, %{seconds: timeout}}], :ok}
  end

  defp cleanup({:timeout_requested, %{seconds: timeout}}, _state) do
    {:timeout, timeout}
  end
end
