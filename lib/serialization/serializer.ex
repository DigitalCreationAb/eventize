defmodule Reactive.Serialization.Serializer do
  @moduledoc """
  Behaviour that specifies how events and snapshots can be serialized and deserialized.
  """

  @callback serialize(input :: term()) :: {:ok, String.t()} | {:error, term()}

  @callback deserialize(input :: String.t(), [type :: String.t() | :atom]) ::
              {:ok, term()} | {:error, term()}
end
