defmodule TestEventBus do
  @moduledoc false

  @behaviour Reactive.Persistence.EventBus

  alias Reactive.Persistence.EventStore.AppendCommand
  alias Reactive.Persistence.EventStore.LoadQuery

  def load_events(stream_name, start \\ :start, max_count \\ :all) do
    GenServer.call(Reactive.Persistence.EventStore, %LoadQuery{
      stream_name: stream_name,
      start: start,
      max_count: max_count
    })
  end

  def append_events(stream_name, events, expected_version \\ :any) do
    GenServer.call(Reactive.Persistence.EventStore, %AppendCommand{
      stream_name: stream_name,
      events: events,
      expected_version: expected_version
    })
  end

  def delete(stream_name, version) do
    GenServer.call(
      Reactive.Persistence.EventStore,
      {:delete_events, stream_name, version}
    )
  end
end
