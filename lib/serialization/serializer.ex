defmodule Reactive.Serialization.Serializer do
  @moduledoc """
  Behaviour that specifies how events and snapshots can be serialized and deserialized.
  """

  @callback serialize(input :: map()) :: {:ok, String.t()} | {:error, term()}

  @callback deserialize(input :: String.t(), type :: :atom | nil) ::
              {:ok, term()} | {:error, term()}
end
