defmodule TestEntityWithoutBehavior do
  @moduledoc false

  use Reactive.Entities.Entity

  def child_spec(id) do
    %{
      id: id,
      start: {__MODULE__, :start_link, [id]},
      type: :worker
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

  def execute({:start, %{:title => title}}, _context) do
    {[{:started, %{title: title}}], %{title: title}}
  end

  def execute(:stop, %{:id => id}) do
    [{:stopped, %{id: id}}]
  end

  defp on(state, {:started, %{:title => title}}) do
    Map.put(state, :title, title)
  end

  defp get_lifespan({:stopped, _data}, _state) do
    :stop
  end
end
