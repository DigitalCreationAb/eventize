defmodule Eventize.Serialization.JasonSerializer do
  @moduledoc """
  A serializer that uses the Jason library.
  """

  @behaviour Eventize.Serialization.Serializer

  @spec serialize(map) :: {:error, any} | {:ok, binary()}
  def serialize(input) do
    try do
      {:ok, Jason.encode!(input)}
    rescue
      err -> {:error, err}
    end
  end

  @spec deserialize(
          binary(),
          atom | nil
        ) :: {:error, any} | {:ok, map}
  def deserialize(input, type \\ nil) do
    try do
      result =
        Jason.decode!(input, keys: :atoms)
        |> to_struct(type)

      {:ok, result}
    rescue
      err -> {:error, err}
    end
  end

  defp to_struct(data, nil), do: data
  defp to_struct(data, struct), do: struct(struct, data)
end
