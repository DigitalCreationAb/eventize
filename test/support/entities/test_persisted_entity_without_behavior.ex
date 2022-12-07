defmodule TestPersistedEntityWithoutBehavior do
  @moduledoc false

  use Reactive.Entities.PersistedEntity

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

  def execute({:start, %{:title => title}}, _context) do
    {[{:started, %{title: title}}], %{title: title}}
  end

  def execute(:get_title, %{:state => state}) do
    %{title: state.title}
  end

  defp on(state, {:started, %{:title => title}}) do
    Map.put(state, :title, title)
  end
end
