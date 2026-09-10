defmodule BookReviews.Cache.Null do
  @moduledoc """
  No-op cache backend used when Redis is not configured.

  Every read is a miss and every write is absorbed, so the application runs
  identically with or without the cache. This is the default backend and the
  key that makes the cache "optional".
  """

  @behaviour BookReviews.CacheBackend

  @impl true
  def get(_prefix, _key), do: :error

  @impl true
  def put(_prefix, _key, _value, _ttl_seconds), do: :ok

  @impl true
  def delete(_prefix, _key), do: :ok

  @impl true
  def delete_pattern(_prefix, _pattern), do: :ok
end