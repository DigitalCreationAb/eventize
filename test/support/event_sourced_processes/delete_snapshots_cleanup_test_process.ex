defmodule Eventize.DeleteSnapshotsCleanupTestProcess do
  @moduledoc false

  use Eventize.EventSourcedProcess

  def start_link(%{id: id} = data) do
    GenServer.start_link(
      __MODULE__,
      data,
      name: {:global, id}
    )
  end

  def execute_call({:delete_snapshots, to}, _from, _context) do
    {[{:delete_requested, to}], :ok}
  end

  def execute_call(:ping, _from, _context) do
    :pong
  end

  def execute_cast({:delete_snapshots, to}, _context) do
    [{:delete_requested, to}]
  end

  def cleanup({:delete_requested, to}, _state) do
    {:delete_snapshots, to}
  end
end
