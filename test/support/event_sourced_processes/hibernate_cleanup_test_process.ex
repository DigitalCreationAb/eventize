defmodule Eventize.HibernateCleanupTestProcess do
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
  def execute_call(:hibernate, _from, _context) do
    {[{:hibernation_requested, %{}}], :ok}
  end

  @impl Eventize.EventSourcedProcess.Cleanup
  def cleanup({:hibernation_requested, _}, _state) do
    :hibernate
  end
end
