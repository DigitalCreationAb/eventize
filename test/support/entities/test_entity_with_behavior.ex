defmodule TestEntityWithBehavior do
  @moduledoc false

  use Eventize.Entities.Entity

  defmodule NotStarted do
    @moduledoc false

    def execute_call({:start, %{title: title}}, _from, _context) do
      {[{:started, %{title: title}}], %{title: title}}
    end

    def execute_cast({:start, %{title: title}}, _context) do
      [{:started, %{title: title}}]
    end
  end

  defmodule Started do
    @moduledoc false

    def execute_call({:start, %{title: title}}, _from, _context) do
      {[{:second_title_updated, %{secondTitle: title}}], %{title: title}}
    end

    def execute_cast({:start, %{title: title}}, _context) do
      [{:second_title_updated, %{secondTitle: title}}]
    end
  end

  def start_link(id) do
    GenServer.start_link(
      __MODULE__,
      %{id: id},
      name: {:global, id}
    )
  end

  @impl true
  def start(_id) do
    {NotStarted, %{}}
  end

  defp apply_event({:started, %{title: title}}, state) do
    {Map.put(state, :title, title), Started}
  end

  defp apply_event({:second_title_updated, %{secondTitle: title}}, state) do
    Map.put(state, :secondTitle, title)
  end
end
