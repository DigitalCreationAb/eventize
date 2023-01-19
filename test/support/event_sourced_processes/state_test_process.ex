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

  @impl true
  def execute_call({:set_state, %{} = state}, _from, _context) do
    {[{:state_set, state}], :ok}
  end

  @impl true
  def execute_call(:ping, _from, _context) do
    :pong
  end

  @impl true
  def execute_cast({:set_state, %{} = state}, _context) do
    [{:state_set, state}]
  end

  @impl true
  def apply_event({:state_set, new_state}, _context) do
    new_state
  end
end
