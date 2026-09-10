defmodule BookReviews.Json do
  @moduledoc """
  JSON helpers used by the cache and search layers.

  MongoDB documents contain `BSON.ObjectId` (and occasionally `Date` /
  `DateTime`) values that the default `Jason` encoding does not understand.
  `normalize/1` converts them into plain JSON-safe values before encoding so
  documents can be round-tripped through Redis or OpenSearch.
  """

  @spec encode!(term()) :: String.t()
  def encode!(value) do
    value
    |> normalize()
    |> Jason.encode!()
  end

  @spec decode(String.t()) :: term()
  def decode(value) do
    Jason.decode!(value)
  end

  def normalize(%BSON.ObjectId{} = id), do: BSON.ObjectId.encode!(id)
  def normalize(%Date{} = d), do: Date.to_iso8601(d)
  def normalize(%DateTime{} = d), do: DateTime.to_iso8601(d)

  def normalize(%_{} = struct) do
    struct
    |> Map.from_struct()
    |> normalize()
  end

  def normalize(map) when is_map(map) do
    Map.new(map, fn {key, value} -> {key, normalize(value)} end)
  end

  def normalize(list) when is_list(list), do: Enum.map(list, &normalize/1)
  def normalize(tuple) when is_tuple(tuple), do: tuple |> Tuple.to_list() |> normalize()
  def normalize(value), do: value
end