defmodule Reactive.Persistence.EventBus do
  @moduledoc """
  A behaviour that specifies that you can load and store events from a event store.
  """

  defmodule EventData do
    @moduledoc """
    Represents a event with payload and a sequence number
    """

    defstruct [:payload, :meta_data, :sequence_number]
  end

  @callback load_events(
              stream_name :: String.t(),
              start :: :start | non_neg_integer(),
              max_count :: :all | non_neg_integer()
            ) ::
              {:ok, version :: non_neg_integer(), events :: list(EventData)} | {:error, term()}

  @callback append_events(
              stream_name :: String.t(),
              events :: list({event :: term(), meta_data :: map()}),
              expected_version :: :any | non_neg_integer()
            ) ::
              {:ok, version :: non_neg_integer(), events :: list(EventData)}
              | {:error, term()}

  @callback delete(stream_name :: String.t(), version :: non_neg_integer()) ::
              :ok | {:error, term()}
end
