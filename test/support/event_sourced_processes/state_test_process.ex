defmodule Eventize.StateTestProcess do
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
  def execute_call({:set_state, %{} = state}, _from, _context) do
    {[{:state_set, state}], :ok}
  end

  @impl Eventize.EventSourcedProcess
  def execute_call(:ping, _from, _context) do
    :pong
  end

  @impl Eventize.EventSourcedProcess
  def execute_cast({:set_state, %{} = state}, _context) do
    [{:state_set, state}]
  end

  @impl Eventize.EventSourcedProcess.EventApplyer
  def apply_event({:state_set, new_state}, _state) do
    new_state
  end
end
