defmodule Eventize.Serialization.Serializer do
  @moduledoc """
  Behaviour that specifies how events and snapshots can be serialized and deserialized.
  """

  @callback serialize(input :: map()) :: {:ok, binary()} | {:error, term()}

  @callback deserialize(input :: binary(), type :: atom | nil) ::
              {:ok, term()} | {:error, term()}
end
