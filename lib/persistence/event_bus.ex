defmodule Reactive.Persistence.EventBus do
  @moduledoc """
  A behaviour that specifies that
  """

  @callback load_events(stream_name :: Any) :: Enumerable.t()

  @callback append_events(stream_name :: Any, events :: Enumerable.t()) ::
              :ok | {:error, error :: Any}
end
