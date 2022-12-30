defmodule Eventize.SnapshotCleanupTestProcess do
  @moduledoc false

  use Eventize.EventSourcedProcess

  def start_link(%{id: id} = data) do
    GenServer.start_link(
      __MODULE__,
      data,
      name: {:global, id}
    )
  end

  def execute_call(:take_snapshot, _from, _context) do
    {[{:snapshot_requested, %{}}], :ok}
  end

  def execute_call(:ping, _from, _context) do
    :pong
  end

  def execute_cast(:take_snapshot, _context) do
    [{:snapshot_requested, %{}}]
  end

  defp apply_event({:state_updated, new_state}, _state) do
    new_state
  end

  defp apply_snapshot({:test_snapshot, new_state}, _state) do
    new_state
  end

  defp cleanup({:snapshot_requested, _}, state, %{sequence_number: version}) do
    {:take_snapshot, {{:test_snapshot, state}, version}}
  end
end
