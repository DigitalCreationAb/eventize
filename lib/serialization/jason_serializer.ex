defmodule Reactive.Serialization.JasonSerializer do
  @moduledoc """
  A serializer that uses the Jason library.
  """

  @behaviour Reactive.Serialization.Serializer

  @spec serialize(map) :: {:error, any} | {:ok, String.t()}
  def serialize(input) do
    Jason.encode(input)
  end

  @spec deserialize(
          String.t(),
          :atom | nil
        ) :: {:error, any} | {:ok, map}
  def deserialize(input, type \\ nil) do
    with {:ok, result} <- Jason.decode(input, keys: :atoms) do
      {:ok, result |> to_struct(type)}
    end
  end

  defp to_struct(data, nil), do: data
  defp to_struct(data, struct), do: struct(struct, data)
end
