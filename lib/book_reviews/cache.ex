defmodule BookReviews.Cache do
  @moduledoc """
  Read-acceleration cache for the read-heavy, expensive query results:

    * the authors overview table,
    * the top 10 rated books and top 50 selling books tables,
    * a book's average review score.

  The cache is an optional layer: it is enabled at startup only when Redis is
  available (see `BookReviews.Application`). When disabled, all operations are
  routed to `BookReviews.Cache.Null`, which behaves as a permanent cache miss
  that never stores anything, so the application runs unchanged without it.
  """

  alias BookReviews.Cache.Null

  @cache_prefix "book_reviews"
  @default_ttl 300

  @doc "Returns the cache backend configured at startup."
  def backend do
    Application.get_env(:book_reviews, :cache_backend, Null)
  end

  @doc "Whether the cache layer is enabled."
  def enabled? do
    backend() != Null
  end

  @doc "Reads `key` from the cache. Returns `{:ok, value}` or `:error`."
  def get(key) do
    backend().get(@cache_prefix, key)
  end

  @doc "Stores `value` under `key` for `ttl_seconds`."
  def put(key, value, ttl_seconds \\ @default_ttl) do
    backend().put(@cache_prefix, key, value, ttl_seconds)
  end

  @doc "Deletes `key` from the cache."
  def delete(key) do
    backend().delete(@cache_prefix, key)
  end

  @doc "Deletes every key that matches `pattern`."
  def delete_pattern(pattern) do
    backend().delete_pattern(@cache_prefix, pattern)
  end

  @doc """
  Computes `fun` and caches it: on a miss the value is fetched and stored,
  on a hit the cached value is returned. Invalidation is the caller's
  responsibility via `delete/1` / `delete_pattern/1`.
  """
  def get_or_compute(key, ttl_seconds \\ @default_ttl, fun) do
    case get(key) do
      {:ok, value} ->
        value

      :error ->
        value = fun.()
        put(key, value, ttl_seconds)
        value
    end
  end
end