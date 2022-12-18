defmodule TestEntityWithoutBehavior do
  @moduledoc false

  use Reactive.Entities.Entity

  def child_spec(id) do
    %{
      id: id,
      start: {__MODULE__, :start_link, [id]}
    }
  end

  def start_link(id) do
    GenServer.start_link(
      __MODULE__,
      id,
      name: {:global, id}
    )
  end

  @impl true
  def start(_id) do
    %{}
  end

  def execute_call({:start, %{title: title}}, _from, _context) do
    {[{:started, %{title: title}}], %{title: title}}
  end

  def execute_call(:stop, _from, %{id: id}) do
    [{:stopped, %{id: id}}]
  end

  def execute_cast({:start, %{title: title}}, _context) do
    [{:started, %{title: title}}]
  end

  def execute_cast(:stop, %{id: id}) do
    [{:stopped, %{id: id}}]
  end

  defp apply_event({:started, %{title: title}}, state) do
    Map.put(state, :title, title)
  end

  defp cleanup({:stopped, _data}, _state) do
    :stop
  end
end
