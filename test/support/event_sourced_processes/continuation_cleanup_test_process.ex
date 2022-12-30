defmodule Eventize.ContinuationCleanupTestProcess do
  @moduledoc false

  use Eventize.EventSourcedProcess

  def start_link(%{id: id} = data) do
    GenServer.start_link(
      __MODULE__,
      data,
      name: {:global, id}
    )
  end

  def execute_call({:set_state_in_continuation, %{} = state}, _from, _context) do
    {[{:continuation_requested, state}], :ok}
  end

  def execute_call(:ping, _from, _context) do
    :pong
  end

  def execute_cast({:set_state_in_continuation, %{} = state}, _context) do
    [{:continuation_requested, state}]
  end

  def handle_continue({:set_state, requested_state}, %{} = entity_state) do
    {:noreply, %{entity_state | state: requested_state}}
  end

  defp cleanup({:continuation_requested, requested_state}, _state) do
    {:continue, {:set_state, requested_state}}
  end
end
