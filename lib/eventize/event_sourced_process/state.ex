defmodule Eventize.EventSourcedProcessState do
  @moduledoc """
  A struct representing the state of a `Eventize.EventSourcedProcess`.
  """

  @type t :: %__MODULE__{
          behavior: atom(),
          state: term(),
          event_bus: Eventize.Persistence.EventStore.event_bus(),
          id: String.t(),
          version: :empty | non_neg_integer(),
          stream_name: String.t(),
          process: atom(),
          start_from: :start | non_neg_integer()
        }

  defstruct [
    :behavior,
    :state,
    :event_bus,
    :id,
    :version,
    :stream_name,
    :process,
    start_from: :start
  ]
end
