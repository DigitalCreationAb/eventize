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

  def execute_call({:set_state, %{} = state}, _from, _context) do
    {[{:state_set, state}], :ok}
  end

  def execute_call(:ping, _from, _context) do
    :pong
  end

  def execute_cast({:set_state, %{} = state}, _context) do
    [{:state_set, state}]
  end

  def apply_event({:state_set, new_state}, _state) do
    new_state
  end
end
