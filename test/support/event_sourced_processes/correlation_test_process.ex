defmodule Eventize.CorrelationTestProcess do
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
  def execute_call({:test, %{}}, _from, %{
        correlation_id: correlation_id,
        causation_id: causation_id
      }) do
    {[{:test_event, %{correlation_id: correlation_id, causation_id: causation_id}}],
     %{correlation_id: correlation_id, causation_id: causation_id}}
  end

  @impl true
  def execute_call(:ping, _from, _context) do
    :pong
  end

  @impl true
  def execute_cast({:test, %{}}, %{correlation_id: correlation_id, causation_id: causation_id}) do
    [{:test_event, %{correlation_id: correlation_id, causation_id: causation_id}}]
  end

  @impl true
  def apply_event({:test_event, event}, %EventContext{state: state, meta_data: meta_data}) do
    Map.put(state, :meta_data_correlation_id, meta_data.correlation_id)
    |> Map.put(:meta_data_causation_id, meta_data.causation_id)
    |> Map.put(:event_correlation_id, event.correlation_id)
    |> Map.put(:event_causation_id, event.causation_id)
  end
end
