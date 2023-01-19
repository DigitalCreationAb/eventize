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

  @impl true
  def execute_call(:take_snapshot, _from, _context) do
    {[{:snapshot_requested, %{}}], :ok}
  end

  @impl true
  def execute_call(:ping, _from, _context) do
    :pong
  end

  @impl true
  def execute_cast(:take_snapshot, _context) do
    [{:snapshot_requested, %{}}]
  end

  @impl true
  def apply_event({:state_updated, new_state}, _context) do
    new_state
  end

  @impl true
  def apply_snapshot({:test_snapshot, new_state}, _context) do
    new_state
  end

  @impl true
  def cleanup(
        {:snapshot_requested, _},
        %CleanupContext{sequence_number: version, state: state}
      ) do
    {:take_snapshot, {{:test_snapshot, state}, version}}
  end
end
