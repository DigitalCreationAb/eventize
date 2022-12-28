defmodule TestPersistedEntityWithoutBehavior do
  @moduledoc false

  use Eventize.Entities.PersistedEntity

  def start_link(%{id: id} = data) do
    GenServer.start_link(
      __MODULE__,
      data,
      name: {:global, id}
    )
  end

  @impl true
  def start(_id) do
    %{title: ""}
  end

  def execute_call({:start, %{title: title}}, _from, _context) do
    {[{:started, %{title: title}}], %{title: title}}
  end

  def execute_call(:get_title, _from, %{state: state}) do
    %{title: state.title}
  end

  def execute_call(:delete_previous, _from, %{state: state}) do
    {[{:deletion_requested, %{}}], %{title: state.title}}
  end

  def execute_call(:take_snapshot, _from, _state) do
    {[{:snapshot_requested, %{}}], %{}}
  end

  def execute_cast({:start, %{title: title}}, _context) do
    [{:started, %{title: title}}]
  end

  defp apply_event({:started, %{title: title}}, state) do
    Map.put(state, :title, title)
  end

  defp apply_snapshot({:entity_snapshot, %{title: title}}, state) do
    Map.put(state, :title, title)
  end

  defp cleanup({:deletion_requested, _data}, _state, %{sequence_number: sequence_number}) do
    [{:delete_events, sequence_number - 1}]
  end

  defp cleanup({:snapshot_requested, _data}, %{title: title}, %{sequence_number: sequence_number}) do
    [
      {:take_snapshot, {{:entity_snapshot, %{title: title}}, sequence_number}},
      {:delete_snapshots, sequence_number - 1}
    ]
  end
end
