defmodule Eventize.Persistence.NilEventBus do
  @moduledoc """
  Helper to get a `EventStore.event_bus` that doesn't store any events.
  """

  alias Eventize.Persistence.EventStore
  alias Eventize.Persistence.EventStore.EventData
  alias Eventize.Persistence.EventStore.SnapshotData

  @doc """
  Returns a `EventStore.event_bus` that doesn't store any events.
  This can be used if you need a process that shouldn't be persisted.
  """
  @spec get :: EventStore.event_bus()
  def get() do
    %{
      load_events: fn _, _, _ -> {:ok, []} end,
      append_events: fn _, events, _ ->
        {:ok,
         events
         |> Enum.map(fn {event, meta_data} ->
           %EventData{
             payload: event,
             meta_data: meta_data,
             sequence_number: 0
           }
         end)}
      end,
      delete_events: fn _, _ -> :ok end,
      load_snapshot: fn _, _ -> {:ok, nil} end,
      append_snapshot: fn _, {snapshot, meta_data}, version ->
        {:ok,
         %SnapshotData{
           payload: snapshot,
           meta_data: meta_data,
           version: version
         }}
      end,
      delete_snapshots: fn _, _ -> :ok end
    }
  end
end
