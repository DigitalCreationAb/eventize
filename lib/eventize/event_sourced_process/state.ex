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
          process: atom()
        }

  defstruct [:behavior, :state, :event_bus, :id, :version, :stream_name, :process]
end
