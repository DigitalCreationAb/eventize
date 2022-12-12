defmodule TestEntityWithBehavior do
  @moduledoc false

  use Reactive.Entities.Entity

  defmodule NotStarted do
    @moduledoc false

    def execute_call({:start, %{:title => title}}, _context) do
      {[{:started, %{title: title}}], %{title: title}}
    end

    def execute_cast({:start, %{:title => title}}, _context) do
      [{:started, %{title: title}}]
    end
  end

  defmodule Started do
    @moduledoc false

    def execute_call({:start, %{:title => title}}, _context) do
      {[{:second_title_updated, %{secondTitle: title}}], %{title: title}}
    end

    def execute_cast({:start, %{:title => title}}, _context) do
      [{:second_title_updated, %{secondTitle: title}}]
    end
  end

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
    {NotStarted, %{}}
  end

  defp on(state, {:started, %{:title => title}}) do
    {Map.put(state, :title, title), Started}
  end

  defp on(state, {:second_title_updated, %{:secondTitle => title}}) do
    Map.put(state, :secondTitle, title)
  end
end
